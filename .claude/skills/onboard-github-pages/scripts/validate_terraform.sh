#!/usr/bin/env bash
# Validates terraform/ syntax without touching the real S3-backed state or
# needing real AWS/Cloudflare/GitHub credentials. Copies the *.tf files into
# an isolated temp dir, swaps in a throwaway local backend, and runs
# `terraform validate` there. Exits non-zero (with terraform's own error
# output) if anything is wrong; prints "Success!" and exits 0 otherwise.
#
# Usage: validate_terraform.sh <path-to-terraform-dir>
set -euo pipefail

TF_DIR="${1:?usage: validate_terraform.sh <path-to-terraform-dir>}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cp -r "$TF_DIR"/*.tf "$TF_DIR"/modules "$WORKDIR"/ 2>/dev/null || cp -r "$TF_DIR"/*.tf "$WORKDIR"/

# GITHUB_TOKEN only needs to be set for `terraform init`/`validate` to not
# error on a missing provider credential — no API calls are made by either
# command, so a dummy value is fine.
export GITHUB_TOKEN="${GITHUB_TOKEN:-dummy-token-for-validate-only}"

(cd "$WORKDIR" && terraform init -input=false -backend=false >/dev/null && terraform validate)
