#!/bin/bash
set -e

# Allow runtime selection of Lua version via LUA_VERSION environment variable.
if [[ -n "${LUA_VERSION:-}" ]]; then
  lenv use "${LUA_VERSION}"
fi

exec "$@"
