#!/usr/bin/env bash
# Sweeps every non-archived repo owned by GITHUB_OWNER and deletes branches
# whose only merged PR has already landed — the backlog that predates (or
# falls outside) GitHub's own "automatically delete head branches" setting,
# which this script also turns on for every repo it finds, so future merges
# clean themselves up without needing this sweep.
#
# Protected: any branch name in PROTECTED_BRANCHES below, and each repo's
# actual default branch regardless of name (belt and suspenders — catches a
# default branch that isn't one of the well-known names).
#
# Usage: scripts/cleanup-merged-branches.sh [--dry-run]
# Requires: gh, authenticated (GH_TOKEN/GITHUB_TOKEN env var, or `gh auth
# login`) as a user/token with `repo` scope (or fine-grained Administration +
# Contents + Pull requests) across every repo owned by GITHUB_OWNER.
set -euo pipefail

GITHUB_OWNER="jyjulianwong"
PROTECTED_BRANCHES=(main master develop dev staging production release gh-pages)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Reads lines from a command's stdout into the named array, in place of
# `mapfile` — not available under macOS's bash 3.2, which this script (like
# scripts/bootstrap.sh) is run under locally.
read_lines() {
  local __arr_name="$1" __line
  eval "$__arr_name=()"
  while IFS= read -r __line; do
    eval "$__arr_name+=(\"\$__line\")"
  done
}

is_protected() {
  local ref="$1" default_branch="$2" name
  [[ "$ref" == "$default_branch" ]] && return 0
  for name in "${PROTECTED_BRANCHES[@]}"; do
    [[ "$ref" == "$name" ]] && return 0
  done
  return 1
}

command -v gh >/dev/null || { echo "error: gh is not installed" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated" >&2; exit 1; }

read_lines repos < <(gh repo list "$GITHUB_OWNER" --no-archived --limit 1000 --json name --jq '.[].name')
echo "Found ${#repos[@]} non-archived repositories owned by $GITHUB_OWNER"

total_deleted=0
total_skipped=0

for repo_name in ${repos[@]+"${repos[@]}"}; do
  full_repo="$GITHUB_OWNER/$repo_name"

  default_branch="$(gh api "repos/$full_repo" --jq '.default_branch')"

  # Enable "automatically delete head branches" so future merges don't add to
  # this backlog. Idempotent — a no-op if already on.
  if [[ $DRY_RUN == false ]]; then
    gh api -X PATCH "repos/$full_repo" -f delete_branch_on_merge=true >/dev/null
  fi

  # Only PRs merged *into* this repo with a head branch *in* this repo (not a
  # contributor's fork, which this token can't delete branches on anyway).
  # FULL_REPO is read back via jq's `env.FULL_REPO` — `gh api --jq` has no
  # `--arg` equivalent to pass it in as a proper jq variable.
  read_lines merged_refs < <(
    FULL_REPO="$full_repo" gh api --paginate "repos/$full_repo/pulls?state=closed&per_page=100" \
      --jq '.[] | select(.merged_at != null and .head.repo != null and .head.repo.full_name == env.FULL_REPO) | .head.ref' \
      | sort -u
  )

  [[ ${#merged_refs[@]} -eq 0 ]] && continue

  for ref in "${merged_refs[@]}"; do
    if is_protected "$ref" "$default_branch"; then
      continue
    fi

    # Already gone (deleted on merge, or by a previous run) — nothing to do.
    if ! gh api "repos/$full_repo/branches/$ref" >/dev/null 2>&1; then
      continue
    fi

    if [[ $DRY_RUN == true ]]; then
      echo "would delete: $full_repo:$ref"
      total_deleted=$((total_deleted + 1))
    elif gh api -X DELETE "repos/$full_repo/git/refs/heads/$ref" >/dev/null 2>&1; then
      echo "deleted: $full_repo:$ref"
      total_deleted=$((total_deleted + 1))
    else
      echo "skipped (delete failed, e.g. still protected or in use): $full_repo:$ref" >&2
      total_skipped=$((total_skipped + 1))
    fi
  done
done

if [[ $DRY_RUN == true ]]; then
  echo "Dry run complete: $total_deleted branch(es) would be deleted"
else
  echo "Cleanup complete: $total_deleted branch(es) deleted, $total_skipped skipped"
fi
