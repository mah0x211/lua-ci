#!/usr/bin/env bash
#
# Validate that the given tag is newer than the latest existing date-based tag.
#
# Expected formats:
#   YYYYMMDD or YYYYMMDD-N (where N is a revision number)
#
# Usage:
#   TAG="20240615-1" ./validate_tag_order.sh
#

set -euo pipefail

current="${TAG}" # expected YYYYMMDD or YYYYMMDD-N

# Find the latest previous date-like tag (excluding current itself)
all_tags="$(git tag --list '20*' | grep -E '^20[0-9]{6}(-[0-9]+)?$' || true)"
prev="$(printf '%s\n' "${all_tags}" | grep -v "^${current}\$" | sort | tail -n1 || true)"

parse_tag() {
    local t="$1"
    local date rev
    date="${t%%-*}"
    rev="${t#*-}"
    if [[ "${rev}" == "${date}" ]]; then
        rev="0"
    fi
    echo "${date} ${rev}"
}

if [[ -n "${prev}" ]]; then
    read -r cur_date cur_rev <<<"$(parse_tag "${current}")"
    read -r prev_date prev_rev <<<"$(parse_tag "${prev}")"

    if (( cur_date < prev_date )) || { (( cur_date == prev_date )) && (( cur_rev <= prev_rev )); }; then
        echo "Tag ${current} is not newer than last tag ${prev}" >&2
        exit 1
    fi

    echo "Tag ${current} is newer than last tag ${prev}"
fi
