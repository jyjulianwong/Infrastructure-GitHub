---
tags: [onboard-github-pages]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

Onboard the repo `jyjulianwong/Demo-Webpack-App` (local clone at
`./demo-webpack-app`, relative to your working directory) to its own
GitHub Pages custom domain, using the onboard-github-pages skill.
`./fake-infra` is a local stand-in for the Infrastructure-GitHub repo's
root (its `terraform/` directory is at `./fake-infra/terraform/`) — make
the DNS-registration edit there instead of in the real Infrastructure-GitHub
repo, and reach the skill's own `scripts/validate_terraform.sh` at its real
path to validate it (pass `./fake-infra/terraform` as the argument).

This is a **local-only dry run** — neither `./demo-webpack-app` nor
`./fake-infra` has a real GitHub remote behind it. Treat these facts as
already established (don't attempt to re-check them via `gh api` against
real GitHub, since there is no real repo to query):

- `jyjulianwong/Demo-Webpack-App` is not archived, is owned by
  `jyjulianwong`, and its default branch is `main`.
- GitHub Pages is already enabled on it: `source.branch = "main"`,
  `source.path = "/"`, `build_type = "workflow"`, `cname = null`.

**Do not run any real `gh api`, `git push`, or `gh pr create` commands** —
there's nothing real to push to. Instead, make every file edit you'd
actually make (in `./demo-webpack-app` and `./fake-infra`), run the real
validation steps the skill calls for, and then write `./report.md`
describing: the subdomain slug you chose, every file you created or
changed (and why), the exact Infrastructure-GitHub map edit, the terraform
validation result, and anything you'd flag as a manual follow-up in either
PR's description.

Input files: demo-webpack-app, fake-infra
