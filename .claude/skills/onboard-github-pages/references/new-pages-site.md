# When GitHub Pages isn't enabled yet

Check this before anything else: `gh api repos/<owner>/<repo>/pages`. A 404
means Pages has never been turned on for this repo — the genuinely
from-scratch case ("I just created a new project repo"), as opposed to
migrating a repo that's had Pages running for a while already (the other
reference files in this directory, written against 9 repos already in that
state).

## Step 1 — is there even a frontend to serve yet?

Run `scripts/detect_build_tool.py <repo_path>`. If it returns `"unknown"`,
there's no recognizable frontend tooling in the repo at all — don't guess.
Ask the user which framework/build approach they're using (or whether
there's no app yet at all and this is premature). Don't scaffold an app;
that's a different task from onboarding one to Pages. If they name a
framework this skill already covers (Vite, CRA, mkdocs, a webpack+CopyPlugin
setup, or a plain static directory), you can scaffold *just the deploy
workflow* for it — see Step 2.

## Step 2 — does a deploy workflow exist?

If `detect_build_tool.py`'s `deploy_workflow` field is empty, there's no
GitHub Actions workflow that would ever publish this app to Pages, enabled
or not. Copy the matching starter from `assets/workflows/` (one per variant
— `vite.yml`, `cra.yml`, `mkdocs.yml`, `webpack.yml`, `raw-static.yml`) into
`.github/workflows/deploy.yml`, filling in the subdomain/repo-name
placeholders. These are the same shape as the real working workflows found
across the 9 repos already migrated — not invented from scratch — so they
should need no debugging beyond the placeholder substitution.

If a deploy workflow already exists, leave it alone — apply the matching
variant's recipe (CNAME placement, base path) from the sibling reference
file as normal, on top of what's already there.

## Step 3 — enable Pages via the API

Don't rely on an implicit auto-enable from pushing to a branch or merging a
workflow — ensure it explicitly, since whether that implicit behavior
exists has changed over GitHub's history and isn't something to assume
silently:

**Workflow build type** (the workflow uses `actions/deploy-pages`) — this
one has no branch dependency, so it can be enabled immediately, even before
the workflow has ever run:

```bash
gh api -X POST repos/<owner>/<repo>/pages -f build_type=workflow
```

**Legacy build type** (a workflow pushes prebuilt files to a branch) — this
*does* need the target branch to already exist with at least one commit, or
the API call fails. If the branch doesn't exist yet (truly first-ever run),
skip this call for now and say so plainly in the PR description: "Pages
will need enabling once this workflow has run at least once and created the
`<branch>` branch — either re-run this step then, or do it once by hand in
Settings → Pages (Source: Deploy from a branch, `<branch>` / `<path>`)."
Don't block the rest of onboarding on this — the CNAME file and DNS PR can
both go out regardless; Pages enablement is the one piece that might need a
second pass.

If the branch already exists (e.g. the repo had Pages manually configured
once before, or you're re-running after an earlier push), go ahead:

```bash
gh api -X POST repos/<owner>/<repo>/pages -f "source[branch]=<branch>" -f "source[path]=/"
```

**Either way**, treat a `409 Conflict` response as success, not an error —
it just means Pages was already enabled (possibly by a previous run of this
same skill, or by hand). Don't fail the whole onboarding over it.

## Step 4 — continue as normal

Once Pages is enabled (or you've documented why it isn't yet), proceed with
the matching variant's CNAME placement + base-path recipe exactly as you
would for an already-running Pages site, then `scripts/set_pages_cname.sh`
(`SKILL.md` step 5 — see `references/custom-domain-api.md` for why this is
a separate, mandatory step and not something the CNAME file handles on its
own), then the DNS registration in `references/infrastructure-github.md`.

If Pages enablement itself had to be deferred (the legacy-branch case in
Step 3, where the target branch doesn't exist yet), defer
`set_pages_cname.sh` along with it — the API call needs Pages to already
be enabled on the repo, which won't be true until that deferred step
actually runs.
