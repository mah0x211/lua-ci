#!/usr/bin/env bash
#
# Validate that the given tag is reachable from master.
#
# Usage:
#   TAG="20240615-1" ./validate_tag_reachable_from_master.sh
#

set -euo pipefail

git fetch origin master --depth=1 --no-tags
if ! git merge-base --is-ancestor "${TAG}" origin/master; then
    echo "Tag ${TAG} is not reachable from master" >&2
    exit 1
fi

echo "Tag ${TAG} is reachable from master"
