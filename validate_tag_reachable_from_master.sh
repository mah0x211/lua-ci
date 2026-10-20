#!/usr/bin/env bash
#
# Validate that the given tag is reachable from master.
#
# Usage:
#   TAG="20240615-1" ./validate_tag_reachable_from_master.sh
#

set -euo pipefail

git fetch --no-tags origin '+refs/heads/master:refs/remotes/origin/master'

if git merge-base --is-ancestor "${TAG:?TAG is required}" refs/remotes/origin/master; then
    echo "Tag ${TAG} is reachable from master"
else
    status=$?
    if (( status == 1 )); then
        echo "Tag ${TAG} is not reachable from master" >&2
    else
        echo "Could not determine whether tag ${TAG} is reachable from master (git exit ${status})" >&2
    fi
    exit "${status}"
fi
