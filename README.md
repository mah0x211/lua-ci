# lua-ci

[![build](https://github.com/mah0x211/lua-ci/actions/workflows/build.yml/badge.svg)](https://github.com/mah0x211/lua-ci/actions/workflows/build.yml)

Custom Docker image for GitHub Actions CI with lenv-managed Lua/LuaRocks.

- Base image: `debian:<suite>-slim` (default: `bookworm-slim`, override via `DEBIAN_SUITE` build-arg)
- Lua/LuaRocks installer: [lenv v0.9.1](https://github.com/mah0x211/lenv)
- Installed Lua versions: `5.1.5`, `5.2.4`, `5.3.6`, `5.4.8`, `LuaJIT v2.1` (switch via `LUA_VERSION` env)
- LuaRocks: latest (3.12.x series)
- Installed tooling and dev libs (for common LuaRocks builds):
  - Build tools: `build-essential`, `pkg-config`, `cmake`, `autoconf`, `automake`, `libtool`
  - Core libs: `libssl-dev`, `libpcre2-dev`, `libreadline-dev`, `libyaml-dev`, `libsqlite3-dev`
  - Coverage: `lcov`
  - Utilities: `curl`, `git`, `unzip`, `xz-utils`, `ca-certificates`

## Build

```sh
docker build -t ghcr.io/mah0x211/lua-ci:latest .

# build with a different Debian suite (e.g. bullseye)
docker build \
  --build-arg DEBIAN_SUITE=bullseye \
  -t ghcr.io/mah0x211/lua-ci:bullseye \
  .
```

For release builds (pushed to GHCR):

```sh
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t ghcr.io/mah0x211/lua-ci:bookworm .
```

## CI / Release workflows (GitHub Actions)

- `build.yml`: runs on branch pushes (tags are ignored; docs/licence-only changes are ignored), builds and smoke-tests (no push).

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
      env:
        LUA_VERSION: ${{ matrix.lua_version }}  # defaults to 5.4.8 if unset
    steps:
      - uses: actions/checkout@v4
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
