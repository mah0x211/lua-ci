ARG DEBIAN_SUITE=trixie

FROM debian:${DEBIAN_SUITE}-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Prefer active mirrors, with archive fallback when a release moves out of them.
RUN set -eux; \
    mkdir -p /etc/apt/mirrors; \
    printf '%s\tpriority:1\n%s\tpriority:2\n' \
      'http://deb.debian.org/debian' 'http://archive.debian.org/debian' \
      > /etc/apt/mirrors/debian.list; \
    printf '%s\tpriority:1\n%s\tpriority:2\n' \
      'http://deb.debian.org/debian-security' 'http://archive.debian.org/debian-security' \
      > /etc/apt/mirrors/debian-security.list; \
    for source in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do \
      if [ -f "${source}" ]; then \
        sed -i \
          -e 's|http://deb.debian.org/debian-security|mirror+file:/etc/apt/mirrors/debian-security.list|g' \
          -e 's|http://deb.debian.org/debian|mirror+file:/etc/apt/mirrors/debian.list|g' \
          "${source}"; \
      fi; \
    done

# Build essentials for compiling Lua/LuaRocks and common native modules.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      clang \
      clang-format \
      gnupg \
      jq \
      openssl \
      build-essential \
      pkg-config \
      cmake \
      autoconf \
      automake \
      libtool \
      libreadline-dev \
      libssl-dev \
      libpcre2-dev \
      libyaml-dev \
      libsqlite3-dev \
      lcov \
      unzip \
      zip \
      xz-utils; \
    rm -rf /var/lib/apt/lists/*

# lenv installation
ARG LENV_VERSION=v0.10.0
ARG TARGETARCH
ENV LENV_ROOT=/usr/local/lenv

# Install lenv binary and global setup with checksum verification.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) LENV_ARCH=x86_64 ;; \
      arm64) LENV_ARCH=arm64 ;; \
      386) LENV_ARCH=i386 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    TMP_DIR="$(mktemp -d)"; \
    ARCHIVE_NAME="lenv_Linux_${LENV_ARCH}.tar.gz"; \
    curl -fsSL "https://github.com/mah0x211/lenv/releases/download/${LENV_VERSION}/${ARCHIVE_NAME}" \
      -o "${TMP_DIR}/${ARCHIVE_NAME}"; \
    curl -fsSL "https://github.com/mah0x211/lenv/releases/download/${LENV_VERSION}/checksums.txt" \
      -o "${TMP_DIR}/checksums.txt"; \
    if ! EXPECTED="$(awk -v archive="${ARCHIVE_NAME}" ' \
      $2 == archive { \
        count++; \
        if (NF != 2 || length($1) != 64 || $1 ~ /[^0-9a-fA-F]/) invalid = 1; \
        hash = $1; \
      } \
      END { \
        if (count != 1 || invalid) exit 1; \
        print tolower(hash); \
      }' "${TMP_DIR}/checksums.txt")"; then \
      echo "Missing, duplicate, or invalid checksum for ${ARCHIVE_NAME}" >&2; \
      exit 1; \
    fi; \
    ACTUAL="$(sha256sum "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"; \
    if [ "${EXPECTED}" != "${ACTUAL}" ]; then \
      echo "Checksum verification failed for ${ARCHIVE_NAME}" >&2; \
      echo "Expected: ${EXPECTED}" >&2; \
      echo "Actual:   ${ACTUAL}" >&2; \
      exit 1; \
    fi; \
    tar -xzf "${TMP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}"; \
    install -m 0755 "${TMP_DIR}/lenv" /usr/local/bin/lenv; \
    rm -rf "${TMP_DIR}"; \
    lenv -g setup

# Keep lenv-managed Lua tools ahead of system binaries.
ENV PATH="${LENV_ROOT}/current/lua_modules/bin:${LENV_ROOT}/current/bin:${PATH}"

ARG LUA_VERSIONS="5.1. 5.2. 5.3. 5.4. lj-v2.1"
ARG LUAROCKS_VERSION=latest

# Fetch version metadata and install Lua + LuaRocks.
RUN set -eux; \
    lenv -g fetch; \
    for ver in ${LUA_VERSIONS}; do \
      if [[ "${ver}" == lj-* ]]; then \
        lenv -g install "${ver}:${LUAROCKS_VERSION}"; \
      else \
        lenv -g install "${ver}:${LUAROCKS_VERSION}" linux; \
      fi; \
    done; \
    lenv -g use "5.4"; \
    find "${LENV_ROOT}/src" -mindepth 1 -delete

FROM builder

LABEL org.opencontainers.image.title="lua-ci" \
      org.opencontainers.image.description="Lua CI base image with lenv-managed Lua/LuaRocks" \
      org.opencontainers.image.source="https://github.com/mah0x211/lua-ci"

ARG LUA_PATH
ARG LUA_CPATH

# Set Lua search paths provided at build time.
ENV LUA_PATH="${LUA_PATH}" \
    LUA_CPATH="${LUA_CPATH}"

# Validate that provided paths match lenv output.
RUN set -eux; \
    normalize_path_list() { \
      printf '%s' "$1" | tr ';' '\n' | sed '/^$/d' | LC_ALL=C sort; \
    }; \
    expected_lua_path="$(lenv -g path lualib)"; \
    expected_lua_cpath="$(lenv -g path luaclib)"; \
    if [ -z "${LUA_PATH}" ] || [ -z "${LUA_CPATH}" ]; then \
      echo "LUA_PATH/LUA_CPATH must be provided via build-args" >&2; \
      exit 1; \
    fi; \
    normalized_lua_path="$(normalize_path_list "${LUA_PATH}")"; \
    normalized_expected_lua_path="$(normalize_path_list "${expected_lua_path}")"; \
    if [ "${normalized_lua_path}" != "${normalized_expected_lua_path}" ]; then \
      echo "LUA_PATH mismatch"; \
      echo "expected: ${expected_lua_path}"; \
      echo "actual:   ${LUA_PATH}"; \
      exit 1; \
    fi; \
    echo "LUA_PATH matches expected value: ${expected_lua_path}"; \
    normalized_lua_cpath="$(normalize_path_list "${LUA_CPATH}")"; \
    normalized_expected_lua_cpath="$(normalize_path_list "${expected_lua_cpath}")"; \
    if [ "${normalized_lua_cpath}" != "${normalized_expected_lua_cpath}" ]; then \
      echo "LUA_CPATH mismatch"; \
      echo "expected: ${expected_lua_cpath}"; \
      echo "actual:   ${LUA_CPATH}"; \
      exit 1; \
    fi; \
    echo "LUA_CPATH matches expected value: ${expected_lua_cpath}"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["lua", "-v"]
