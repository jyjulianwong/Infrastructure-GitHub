# Registering the new subdomain in Infrastructure-GitHub

This repo's `terraform/pages_domains.tf` creates one Cloudflare DNS CNAME
record per entry in `terraform/variables.tf`'s `pages_domain_repositories`
map — see that file's own description and `pages_domains.tf`'s header
comment for the full design rationale (DNS-only here; the GitHub-side
`cname` setting comes from the CNAME file committed in the project repo's
own PR, not from Terraform).

## Edit the map

Add one line to `pages_domain_repositories`'s `default` block in
`terraform/variables.tf`:

```hcl
"<Exact-GitHub-Repo-Name>" = "<slug>"
```

Keep the map **alphabetical by key** — that's how every existing entry is
ordered, and an out-of-order insert will look like an unrelated diff to
whoever reviews the PR. Use the exact GitHub repo name as it appears in the
URL (case-sensitive), not the local directory name if the two ever differ.

## Pick the slug

Default: the repo name, lowercased, with underscores (if any) left as
hyphens — i.e. just lowercase the existing hyphenated name
(`Market-Regime-Detector` → `market-regime-detector`). This has been the
consistent convention across every repo onboarded so far. Only deviate if
the user explicitly asks for a different subdomain for this one repo.

Before finalizing, check the map for a slug collision — two repos can't
share a subdomain. `grep` the existing values; if the default slug is
already taken (unlikely given the 1:1 naming convention, but check
anyway), ask the user how they want to disambiguate rather than guessing.

## Validate before pushing

Run `terraform fmt` on the file, then:

```bash
bash .claude/skills/onboard-github-pages/scripts/validate_terraform.sh terraform
```

This confirms the HCL is syntactically valid and the map's type checks out,
without touching the real S3-backed state or needing real AWS/Cloudflare
credentials. If it fails, you have a syntax error in the edit — fix it
before committing; don't commit something you haven't validated.

## Branch, commit, PR

This repo enforces branch protection (`branch_ruleset.tf` — direct pushes to
`main` are blocked), so this always goes through a PR, same as every other
change here:

```bash
git fetch origin main
git checkout -b onboard-<slug>-pages origin/main
# ...edit terraform/variables.tf...
git add terraform/variables.tf
git commit -m "Register <slug>.jyjwong.com for <Repo-Name>"
git push -u origin onboard-<slug>-pages
gh pr create --title "Register <slug>.jyjwong.com for <Repo-Name>" --body-file <...>
```

Always branch from a freshly-fetched `origin/main`, not from whatever
branch happened to be checked out locally — a stale local branch could
silently drop or conflict with another onboarding PR that merged since you
last pulled.

**If this skill is being run for several repos back-to-back**, each one
still gets its own branch and PR here, forked fresh from `origin/main` each
time, the same way `branch_ruleset.tf`'s header comments describe scoping
every module file to one concern. Don't batch multiple repos' DNS entries
into one PR unless the user explicitly asks for that — one onboarding, one
PR, mirrors how the 9 original migrations were done and keeps each PR's
blast radius reviewable.

## Note the dependency in the project repo's own PR

The project repo's PR (CNAME file, base-path fix) should mention that the
DNS CNAME record is added in this PR, link to it, and say plainly that the
`CLOUDFLARE_API_TOKEN` secret must already be configured in this repo's
Actions settings for `terraform apply` to pick up the new record on merge —
see this repo's own `README.md` if that secret doesn't exist yet.
