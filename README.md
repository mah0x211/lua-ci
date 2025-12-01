# lua-ci

[![build](https://github.com/mah0x211/lua-ci/actions/workflows/build.yml/badge.svg)](https://github.com/mah0x211/lua-ci/actions/workflows/build.yml)

Custom Docker image for GitHub Actions CI with lenv-managed Lua/LuaRocks.

- Base image: `debian:<suite>-slim` (default: `bookworm-slim`, override via `DEBIAN_SUITE` build-arg; images are built for `bullseye` and `bookworm`)
- Lua/LuaRocks installer: [lenv v0.9.1](https://github.com/mah0x211/lenv)
- Installed Lua versions: `5.1.x`, `5.2.x`, `5.3.x`, `5.4.x`, `LuaJIT v2.1` (latest patch available in lenv; switch via `LUA_VERSION` env)
- LuaRocks: latest available in lenv
- Installed tooling and dev libs (for common LuaRocks builds):
  - Build tools: `build-essential`, `pkg-config`, `cmake`, `autoconf`, `automake`, `libtool`
  - Core libs: `libssl-dev`, `libpcre2-dev`, `libreadline-dev`, `libyaml-dev`, `libsqlite3-dev`
  - Coverage: `lcov`
  - Utilities: `curl`, `git`, `unzip`, `xz-utils`, `ca-certificates`

## Build

> Note: The Dockerfile expects `LUA_PATH` / `LUA_CPATH` via build-args and verifies them against lenv output. For local builds, follow a two-step flow: extract paths first, then rebuild with those args.

Example (bookworm):

```sh
# 1) Build & load the builder stage
docker build --target builder -t ghcr.io/mah0x211/lua-ci:local .

# 2) Get paths from lenv
LUA_PATH=$(docker run --rm ghcr.io/mah0x211/lua-ci:local lenv -g path lualib)
LUA_CPATH=$(docker run --rm ghcr.io/mah0x211/lua-ci:local lenv -g path luaclib)

# 3) Rebuild final image with build-args (local)
docker build \
  --build-arg LUA_PATH="${LUA_PATH}" \
  --build-arg LUA_CPATH="${LUA_CPATH}" \
  -t ghcr.io/mah0x211/lua-ci:latest .
```

For another suite (e.g., bullseye), add `--build-arg DEBIAN_SUITE=bullseye` to both builds.

## CI / Release workflows (GitHub Actions)

- `build.yml`: runs on branch pushes (tags are ignored; docs/licence-only changes are ignored), builds and smoke-tests (no push).
- `release.yml`: runs when a date-based Git tag is pushed (e.g. `20250521` or `20250521-1`, and only if the tag is reachable from `master`), builds/pushes `bookworm`/`bullseye` images to GHCR with tags:
  - `${suite}-${git_tag}` (e.g. `bookworm-20250521-1`)
  - `${suite}` (rolling)
  - `latest` (only for ${LATEST_SUITE} in workflow; default bookworm)

## Use

### GitHub Actions (container job)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lua_version:  # use latest patch versions
          - 5.1.
          - 5.2.
          - 5.3.
          - 5.4.
          - lj-v2.1
    container:
      image: ghcr.io/mah0x211/lua-ci:latest
    steps:
      - uses: actions/checkout@v4
      - name: Switch Lua version
        run: |
          lenv -g use ${{ matrix.lua_version }}
          lua -v || true
      - name: Show versions
        run: |
          lua -v
          luarocks --version
      - name: Run tests
        run: |
          # your test commands here
          lua your_test.lua
```

### Local docker run

```sh
docker run --rm ghcr.io/mah0x211/lua-ci:latest lua -v
docker run --rm ghcr.io/mah0x211/lua-ci:latest luarocks --version

# Use a different Lua version (e.g. 5.1.5)
docker run --rm -e LUA_VERSION=5.1.5 ghcr.io/mah0x211/lua-ci:latest lua -v

# Use LuaJIT
docker run --rm -e LUA_VERSION=lj-v2.1 ghcr.io/mah0x211/lua-ci:latest lua -v
```
