ARG DEBIAN_SUITE=bookworm
FROM debian:${DEBIAN_SUITE}-slim

LABEL org.opencontainers.image.title="lua-ci" \
      org.opencontainers.image.description="Lua CI base image with lenv-managed Lua/LuaRocks" \
      org.opencontainers.image.source="https://github.com/mah0x211/lua-ci"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build essentials for compiling Lua/LuaRocks and common native modules.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
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
      xz-utils; \
    rm -rf /var/lib/apt/lists/*

ARG LENV_VERSION=v0.9.1
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
    EXPECTED="$(grep "${ARCHIVE_NAME}" "${TMP_DIR}/checksums.txt" | awk '{print $1}')" || true; \
    ACTUAL="$(sha256sum "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"; \
    if [ -n "${EXPECTED}" ] && [ "${EXPECTED}" != "${ACTUAL}" ]; then \
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
    lenv -g path > /etc/profile.d/lenv.sh; \
    rm -rf "${LENV_ROOT}/src"; \
    mkdir -p "${LENV_ROOT}/src"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["lua", "-v"]
