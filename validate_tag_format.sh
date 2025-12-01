#!/usr/bin/env bash
#
# Validate that the given tag matches the expected date-based format.
#
# Expected formats:
#   YYYYMMDD or YYYYMMDD-N (where N is a revision number)
#
# Usage:
#   TAG="20240615-1" ./validate_tag_format.sh
#

set -euo pipefail

if [[ ! "${TAG}" =~ ^20[0-9]{6}(-[0-9]+)?$ ]]; then
    echo "Tag ${TAG} does not match expected pattern YYYYMMDD or YYYYMMDD-N" >&2
    exit 1
fi

echo "Tag ${TAG} matches expected format."
