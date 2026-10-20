#!/bin/bash
set -euo pipefail

image="$1"

echo "::group::Entrypoint: offline startup and command forwarding"
docker run --rm --network none "${image}" true
docker run --rm --network none -e LUA_VERSION= "${image}" true
if docker run --rm --network none "${image}" bash -euc '
  test "$#" = 2
  test "$1" = "space value"
  test "$2" = "*literal"
  exit 23
' payload "space value" "*literal"; then
  echo "Expected the container command to exit with status 23" >&2
  exit 1
else
  test "$?" = 23
fi
echo "::endgroup::"

echo "::group::Entrypoint: reuse, LuaRocks suffixes, and missing Lua"
docker run --rm -i --entrypoint bash "${image}" -euo pipefail <<'BASH'
lua_version="$(lenv -g current lua)"
lua_version="${lua_version#*/}"
rocks_version="$(lenv -g current luarocks)"
rocks_version="${rocks_version#*/}"
identity="$(stat -Lc '%d:%i' "${LENV_ROOT}/current/bin/lua")"

# An explicit LuaRocks suffix must select that version and reuse installed Lua.
LUA_VERSION="${lua_version}:${rocks_version}" docker-entrypoint.sh true
test "$(lenv -g current lua)" = "lua/${lua_version}"
test "$(lenv -g current luarocks)" = "luarocks/${rocks_version}"
test "$(stat -Lc '%d:%i' "${LENV_ROOT}/current/bin/lua")" = "${identity}"

# A trailing colon must not implicitly install LuaRocks.
lenv -g uninstall ":${rocks_version}"
LUA_VERSION="${lua_version}:" docker-entrypoint.sh true
test -z "$(lenv -g current luarocks)"

# Without a suffix, install and select LuaRocks again.
LUA_VERSION="${lua_version}" docker-entrypoint.sh luarocks --version
test -n "$(lenv -g current luarocks)"

# Remove a non-current version through lenv, then require the entrypoint to
# install it again. Lua 5.1 also requires an explicit Linux build target.
lenv -g use 5.1.
missing_version="$(lenv -g current lua)"
missing_version="${missing_version#*/}"
lenv -g use 5.4.
lenv -g uninstall "${missing_version}"
LUA_VERSION="${missing_version}" docker-entrypoint.sh bash -euc '
  lua -e "assert(_VERSION == \"Lua 5.1\")"
  luarocks --version
'
test "$(lenv -g current lua)" = "lua/${missing_version}"
test -n "$(lenv -g current luarocks)"
BASH
echo "::endgroup::"

echo "::group::Entrypoint: failed refresh prevents command execution"
if out="$(docker run --rm --network none -e LUA_VERSION=5.4. "${image}" \
    bash -c 'echo PAYLOAD_EXECUTED' 2>&1)"; then
  printf '%s\n' "${out}"
  echo "Expected version refresh to fail without network access" >&2
  exit 1
fi
printf '%s\n' "${out}"
grep -Fq 'version refresh failed' <<<"${out}"
if grep -Fq 'PAYLOAD_EXECUTED' <<<"${out}"; then
  echo "The container command ran after a failed refresh" >&2
  exit 1
fi
echo "::endgroup::"
