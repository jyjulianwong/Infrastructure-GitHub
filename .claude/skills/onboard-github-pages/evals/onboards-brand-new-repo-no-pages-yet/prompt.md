---
tags: [onboard-github-pages]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

I just created a new project repo, `jyjulianwong/Demo-Brand-New-App` (local
clone at `./demo-brand-new-app`, relative to your working directory), and
want it live under jyjwong.com. Onboard it using the onboard-github-pages
skill. `./fake-infra` is a local stand-in for the Infrastructure-GitHub
repo's root (its `terraform/` directory is at `./fake-infra/terraform/`) —
make the DNS-registration edit there instead of in the real
Infrastructure-GitHub repo, and reach the skill's own
`scripts/validate_terraform.sh` at its real path to validate it (pass
`./fake-infra/terraform` as the argument).

This is a **local-only dry run** — neither `./demo-brand-new-app` nor
`./fake-infra` has a real GitHub remote behind it. Treat these facts as
already established (don't attempt to re-check them via `gh api` against
real GitHub, since there is no real repo to query):

- `jyjulianwong/Demo-Brand-New-App` is not archived, is owned by
  `jyjulianwong`, and its default branch is `main`.
- GitHub Pages has never been enabled on it — `gh api
  repos/jyjulianwong/Demo-Brand-New-App/pages` would return a 404.
- There is no `.github/workflows/` directory at all yet (confirm this
  yourself by looking — it's true, not a trick).

**Do not run any real `gh api`, `git push`, or `gh pr create` commands** —
there's nothing real to push to. Where the skill calls for an actual
`gh api -X POST .../pages` enablement call, don't run it — just state in
your report exactly which call you would make and why. Make every file
edit you'd actually make (in `./demo-brand-new-app` and `./fake-infra`),
run the real validation steps the skill calls for, and then write
`./report.md` describing: the subdomain slug you chose, every file you
created or changed (and why, including any new workflow file), the exact
Infrastructure-GitHub map edit, the terraform validation result, the
Pages-enablement API call you'd make, and anything you'd flag as a manual
follow-up in either PR's description.

Input files: demo-brand-new-app, fake-infra
