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
export LC_ALL=C

# The workflow validates TAG with validate_tag_format.sh first.
current="${TAG:?TAG is required}"

# Keep Git failures separate from an empty set of matching tags.
all_tags="$(git tag --list '20*')"
prev="$(while IFS= read -r tag; do
    if [[ "${tag}" != "${current}" && "${tag}" =~ ^20[0-9]{6}(-[0-9]+)?$ ]]; then
        printf '%s\n' "${tag}"
    fi
done <<<"${all_tags}" | sort -t- -k1,1n -k2,2n | tail -n1)"

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
    # -C -u checks strictly increasing numeric keys, including equal values
    # written with leading zeros, without shell integer arithmetic.
    if ! printf '%s\n' "$(parse_tag "${prev}")" "$(parse_tag "${current}")" |
        sort -C -u -k1,1n -k2,2n; then
        echo "Tag ${current} is not newer than last tag ${prev}" >&2
        exit 1
    fi

    echo "Tag ${current} is newer than last tag ${prev}"
fi
