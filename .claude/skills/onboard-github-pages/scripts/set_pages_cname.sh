#!/usr/bin/env bash
# Explicitly sets a GitHub Pages site's custom domain via the REST API, and
# verifies it actually took.
#
# Why this exists (see references/custom-domain-api.md for the full story):
# GitHub auto-detects a custom domain from a committed CNAME file only for
# "legacy" (branch-based) Pages sites. For "workflow" build-type sites
# (Actions-based actions/deploy-pages — what the vite, mkdocs, and
# webpack-copy variants in this skill all normally produce), that
# auto-detection never happens. The CNAME file can be sitting in the
# deployed artifact and the custom domain will still show as unset
# (`cname: null` via the API) and the site will 404 on that domain
# indefinitely, with no error anywhere telling you why. Confirmed live on
# four real repos (2026-11-14): the fix in every case was this one explicit
# API call, with no other change needed.
#
# Safe to call unconditionally regardless of build type — on a "legacy"
# site where the file-based auto-detect already set the same value, this
# is a harmless no-op confirmation, not a conflicting write.
#
# Usage: set_pages_cname.sh <owner>/<repo> <subdomain.domain.tld>
set -euo pipefail

REPO="${1:?usage: set_pages_cname.sh <owner>/<repo> <cname>}"
CNAME="${2:?usage: set_pages_cname.sh <owner>/<repo> <cname>}"

gh api -X PUT "repos/${REPO}/pages" -f "cname=${CNAME}" >/dev/null

actual="$(gh api "repos/${REPO}/pages" --jq '.cname')"
if [ "$actual" != "$CNAME" ]; then
  echo "ERROR: ${REPO}'s Pages cname is '${actual}', expected '${CNAME}'" >&2
  exit 1
fi
echo "OK: ${REPO}'s Pages cname is now ${actual}"
