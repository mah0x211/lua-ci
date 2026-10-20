#!/bin/bash
set -e

# Prepare the requested runtime before executing the container command.
if [[ -n "${LUA_VERSION:-}" ]]; then
  version="${LUA_VERSION}"
  if [[ "${version}" != *:* ]]; then
    version="${version}:latest"
  fi
  if [[ "${version}" == lj-* ]]; then
    lenv -g install --fetch --if-missing "${version}"
  else
    lenv -g install --fetch --if-missing "${version}" linux
  fi
fi

exec "$@"
