#!/usr/bin/env bash
#
# Compute GHCR image tags for a release.
#
# Outputs a multi-line "tags<<EOF ... EOF" block (the GitHub Actions
# multi-value output format), appended to $GITHUB_OUTPUT. When
# $GITHUB_OUTPUT is unset (local testing) it is written to stdout instead.
#
# Inputs (env):
#   IMAGE_NAME        e.g. ghcr.io/mah0x211/lua-ci
#   TAG               git tag, e.g. 20250521-1
#   SUITE             debian suite, e.g. bookworm
#   LATEST_SUITE      suite that receives the rolling "latest" tag
#   WITH_ARCH_SUFFIX  if non-empty, append "-${ARCH}" to every tag
#   ARCH              architecture suffix (amd64 / arm64); required when
#                     WITH_ARCH_SUFFIX is set
#
# Without WITH_ARCH_SUFFIX:
#   ${IMAGE_NAME}:${SUITE}-${TAG}
#   ${IMAGE_NAME}:${SUITE}
#   ${IMAGE_NAME}:latest                       (only if SUITE == LATEST_SUITE)
#
# With WITH_ARCH_SUFFIX=1 and ARCH=amd64, each tag gains a "-amd64" suffix,
# e.g. ${IMAGE_NAME}:${SUITE}-${TAG}-amd64, ${IMAGE_NAME}:latest-amd64.

set -euo pipefail

: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${TAG:?TAG is required}"
: "${SUITE:?SUITE is required}"
: "${LATEST_SUITE:?LATEST_SUITE is required}"

TAGS=("${IMAGE_NAME}:${SUITE}-${TAG}" "${IMAGE_NAME}:${SUITE}")
if [[ "${SUITE}" == "${LATEST_SUITE}" ]]; then
  TAGS+=("${IMAGE_NAME}:latest")
fi

if [[ -n "${WITH_ARCH_SUFFIX:-}" ]]; then
  : "${ARCH:?ARCH is required when WITH_ARCH_SUFFIX is set}"
  TAGS=("${TAGS[@]/%/-${ARCH}}")
fi

out="${GITHUB_OUTPUT:-/dev/stdout}"
{
  echo 'tags<<EOF'
  for t in "${TAGS[@]}"; do
    echo "$t"
  done
  echo 'EOF'
} >> "${out}"
