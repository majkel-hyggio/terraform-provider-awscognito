#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Provenance check for the majkel-hyggio/awscognito fork.
#
# Proves that the tree being released is exactly:
#   upstream hashicorp/terraform-provider-aws tag UPSTREAM_TAG (pinned commit)
#   + the diff of PR #48388 between PR_BASE and PR_HEAD (pinned commits)
#   + release tooling only: .github/**, .goreleaser.yml, README.md
#
# How: rebuild the expected tree (upstream tree + PR diff) in a temporary
# index and compare it with the tree of TARGET. Every path that differs must
# match ALLOWED_RE. Any change to Go code, go.mod/go.sum, docs or anything
# else outside the PR fails the check.
#
# Usage: check-provenance.sh [TARGET]   (default: HEAD)
# Needs: git, network access to github.com. Read-only for the repository
# except for refs under refs/provenance/*.

set -euo pipefail

UPSTREAM_REPO="https://github.com/hashicorp/terraform-provider-aws.git"
UPSTREAM_TAG="v6.54.0"
UPSTREAM_COMMIT="8ca5b8dac50747f51e02a122d058f6eebd58ba19"
PR_NUMBER="48388"
PR_BASE="7c12155825dfc23da149a68a6bda11439c8f7ab3"
PR_HEAD="3b355c5422895511ac24509c4cb66bbe57d02a07"
ALLOWED_RE='^(\.github/.+|\.goreleaser\.yml|README\.md)$'

TARGET="${1:-HEAD}"

fail() {
  echo "::error::provenance: $*" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

target_commit="$(git rev-parse --verify "${TARGET}^{commit}")"
target_tree="$(git rev-parse "${target_commit}^{tree}")"
echo "target:   ${TARGET} = ${target_commit} (tree ${target_tree})"

# 1. Upstream tag must still point at the pinned commit.
git fetch --quiet --no-tags --depth=1 "$UPSTREAM_REPO" \
  "+refs/tags/${UPSTREAM_TAG}:refs/provenance/upstream-tag"
tag_commit="$(git rev-parse "refs/provenance/upstream-tag^{commit}")"
[ "$tag_commit" = "$UPSTREAM_COMMIT" ] ||
  fail "upstream ${UPSTREAM_TAG} is ${tag_commit}, expected ${UPSTREAM_COMMIT}"
echo "upstream: ${UPSTREAM_TAG} = ${UPSTREAM_COMMIT}"

# 2. PR diff from the pinned base and head (fetched by SHA, immutable).
git fetch --quiet --no-tags --depth=1 "$UPSTREAM_REPO" \
  "+${PR_BASE}:refs/provenance/pr-base" \
  "+${PR_HEAD}:refs/provenance/pr-head"
git -c core.quotePath=false diff --no-ext-diff --no-color --no-renames \
  --binary --full-index "$PR_BASE" "$PR_HEAD" >"$work/pr.diff"
echo "PR #${PR_NUMBER}: ${PR_BASE}..${PR_HEAD}"
git diff --no-renames --stat "$PR_BASE" "$PR_HEAD" | sed 's/^/  /'

# 3. Expected tree = upstream tree + PR diff (index only, no checkout).
export GIT_INDEX_FILE="$work/index"
git read-tree "$UPSTREAM_COMMIT"
git apply --cached "$work/pr.diff" || fail "PR diff does not apply to ${UPSTREAM_TAG}"
expected_tree="$(git write-tree)"
unset GIT_INDEX_FILE
echo "expected: upstream + PR = tree ${expected_tree}"

# 4. Everything else that differs must be release tooling.
git -c core.quotePath=false diff --no-renames --name-status \
  "$expected_tree" "$target_tree" >"$work/extra.txt"
echo "release tooling changes (vs upstream + PR):"
sed 's/^/  /' "$work/extra.txt"

bad="$(cut -f2- "$work/extra.txt" | grep -Ev "$ALLOWED_RE" || true)"
if [ -n "$bad" ]; then
  echo "$bad" | sed 's/^/  NOT ALLOWED: /' >&2
  fail "changes outside upstream ${UPSTREAM_TAG} + PR #${PR_NUMBER} + release tooling"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Provenance OK"
    echo ""
    echo "- upstream \`${UPSTREAM_TAG}\` = \`${UPSTREAM_COMMIT}\`"
    echo "- PR #${PR_NUMBER} \`${PR_BASE:0:7}..${PR_HEAD:0:7}\`"
    echo "- released commit \`${target_commit}\`"
    echo "- other changed paths: $(wc -l <"$work/extra.txt") (all under the allow-list)"
  } >>"$GITHUB_STEP_SUMMARY"
fi

echo "provenance OK"
