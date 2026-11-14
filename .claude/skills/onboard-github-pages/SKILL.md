---
name: onboard-github-pages
description: Onboards a jyjulianwong/jyjulianwong-owned repo's GitHub Pages site onto its own <repo-slug>.jyjwong.com subdomain — adding the right CNAME file and fixing the build's base path for whichever tool it uses (Vite, Create React App, mkdocs, webpack, or a raw static client/ dir), enabling Pages first if it isn't on yet, explicitly setting the custom domain via the Pages API (the CNAME file alone silently doesn't work for Actions-based "workflow" build-type sites), and registering the Cloudflare DNS record in this Infrastructure-GitHub repo — then opens a PR in each repo touched. Use this whenever the user asks to onboard, migrate, or set up GitHub Pages / a custom domain for one of their project repos, says things like "put X on its own subdomain", "register X in Infrastructure-GitHub", "set up jyjwong.com for X", or has just created a new project repo and wants it live under jyjwong.com — even if they don't use the words "GitHub Pages" or "Cloudflare" explicitly.
---

# Onboard a repo to GitHub Pages on jyjwong.com

This automates the two-repo operation of putting one project's GitHub Pages
site on `<slug>.jyjwong.com` instead of `jyjulianwong.github.io/<repo>/`:
edit the project repo (CNAME file + base-path fix), edit this repo
(register the Cloudflare DNS record), and open a PR for each. It
generalizes the manual migration done for 9 existing repos in one earlier
session — the five build-tool recipes here (`references/*.md`) are copied
from what actually worked on those repos, not invented in the abstract.

**Scope**: only `jyjulianwong`-owned repos. A fork or a repo owned by
another account/org (there are several siblings in this account's working
directory that aren't `jyjulianwong`'s own — check `gh repo view
<owner>/<repo> --json owner` if unsure) is out of scope; say so and stop
rather than opening a PR somewhere it doesn't belong.

## Inputs

- **Target repo**: a name or local path. Resolve it as a sibling directory
  of this repo (`../`) first; if not found locally, ask whether to clone it
  or confirm the repo exists on GitHub at all.
- **Subdomain slug** (optional override): defaults to the repo name,
  lowercased — see `references/infrastructure-github.md`'s "Pick the slug"
  section before overriding this.

If the user names several repos in one request, run through this whole
procedure once per repo, each with its own pair of PRs — don't batch them
(see `references/infrastructure-github.md` for why).

## Procedure

1. **Check scope and archival state.**
   `gh api repos/jyjulianwong/<repo> --jq '{owner: .owner.login, archived: .archived, default_branch: .default_branch}'`.
   Stop immediately (no edits, no branches) if the repo is archived — tell
   the user to unarchive it first, the same blocker hit for two of the nine
   original repos. Stop if it's not `jyjulianwong`-owned, per Scope above.

2. **Check whether Pages is enabled.**
   `gh api repos/jyjulianwong/<repo>/pages`. A 404 means it isn't — follow
   `references/new-pages-site.md` in full before continuing; it covers
   detecting or scaffolding a deploy workflow and enabling Pages via the
   API. Otherwise, note the existing `source.branch`/`source.path` for
   context and move on.

3. **Detect the build tool.**
   ```bash
   python3 .claude/skills/onboard-github-pages/scripts/detect_build_tool.py <repo_path>
   ```
   Read the matching reference file for the `variant` it reports:
   `references/vite.md`, `references/cra.md`, `references/mkdocs.md`,
   `references/webpack-copy.md`, or `references/raw-static.md`. If it comes
   back `"unknown"` and Pages was already enabled (so this isn't the
   from-scratch case `new-pages-site.md` covers), stop and describe what
   you found to the user rather than guessing at a recipe that might not
   fit — a wrong guess here means a broken production site, not just a
   failed attempt.

4. **Apply that variant's recipe** in the target repo: add the `CNAME`
   file at the right path, fix the base path (or confirm there isn't one to
   fix), and fix any self-referential URLs the reference file flags.
   Flag — in the PR body, not as a code edit — anything that lives in a
   secret, a deployed env var, or another service's config (every
   reference file calls these out explicitly where they apply).

5. **Set the custom domain via the Pages API directly** — always, for
   every variant, regardless of build type:
   ```bash
   bash .claude/skills/onboard-github-pages/scripts/set_pages_cname.sh jyjulianwong/<repo> <slug>.jyjwong.com
   ```
   This is not optional and not deferrable to "after the PR merges." See
   `references/custom-domain-api.md` for the full story, but the short
   version: GitHub only auto-configures a custom domain from a committed
   `CNAME` file on *legacy* (branch-based) Pages sites. On *workflow*
   (Actions-based `deploy-pages`) sites — which is what the `vite`,
   `mkdocs`, and `webpack-copy` variants normally produce — the CNAME file
   can be sitting correctly in the deployed artifact and the site will
   still 404 on the custom domain forever, with `cname: null` and no error
   anywhere. This call works immediately, independent of whether the
   project repo's PR has merged yet or Pages has ever deployed — it sets
   Pages' own site record, not something derived from deployed content.
   Running it on a *legacy* site is a harmless no-op (the value's already
   right); there's no reliable way to predict build type from the variant
   alone, so don't try to skip this based on which variant was detected.

6. **Commit, push, and open the project repo's PR.**
   New branch from the target repo's default branch (check whether it's
   `main` or something else — one of the nine was `master`). PR body
   should state: what changed, why (the subdomain being moved to), the
   dependency on this repo's DNS PR (step 7, link it once it exists), and
   any flagged manual follow-ups from step 4 as an explicit checklist.

7. **Register the DNS record in this repo.**
   Follow `references/infrastructure-github.md` in full: edit
   `terraform/variables.tf`'s `pages_domain_repositories` map, validate,
   branch, commit, push, open the PR. Link back to the project repo's PR
   from step 6.

8. **Verify, don't just assume.** Once DNS has had a chance to propagate
   (the Infrastructure-GitHub PR needs to be merged and applied first):
   ```bash
   dig <slug>.jyjwong.com +short                      # should resolve to jyjulianwong.github.io.
   curl -sI http://<slug>.jyjwong.com | head -3        # should be 200, not a GitHub 404 page
   gh api repos/jyjulianwong/<repo>/pages --jq '.cname'  # should echo the slug back, not null
   ```
   A `200` that's actually a stale cached `404` from before step 5 ran is
   a real possibility (GitHub's CDN caches error responses per-edge-node) —
   see `references/custom-domain-api.md`'s last section for how to
   recognize that specifically and why it clears on its own.

9. **Summarize to the user.** Both PR links, the chosen slug, and a short
   list of anything that still needs their input beyond merging — a
   secret/env var/other-service update flagged in step 4, a one-time
   `CLOUDFLARE_API_TOKEN` setup if this is the first time DNS has been
   registered this way, or a Pages-enablement follow-up from step 2. Don't
   silently drop these into the PR body and assume they'll be read —
   say them out loud too, the same way the end-of-task summary worked for
   the original 9-repo migration.

## What "done" looks like

Two open PRs (three if Pages needed enabling and the branch didn't exist
yet for the legacy-build-type case in `new-pages-site.md`'s Step 3 — that
one PR has to land and run once before Pages can actually be enabled),
plus the custom domain already set via the API in step 5 (that part isn't
gated on either PR merging). Nothing is merged by this skill — merging is
always the user's call, same as every PR opened during the original
migration — but the Pages API call in step 5 is a live, immediate change
to GitHub's config, not a PR; it's the one piece of this skill's work that
isn't waiting on review.
