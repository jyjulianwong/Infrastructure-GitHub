# Variant: cra

Detected when `package.json` depends on `react-scripts`. `detect_build_tool.py`
reports the current `homepage` field and whether a `public/` dir exists.

## CNAME placement

Add `public/CNAME` containing exactly the subdomain, e.g.
`mbootcamp-grouper-webapp.jyjwong.com`. CRA copies `public/*` verbatim into
`build/` on every `npm run build` — same mechanism as Vite's `publicDir`,
different default folder name coincidence aside.

## Base path fix

CRA derives `PUBLIC_URL` (used for every `%PUBLIC_URL%` placeholder in
`public/index.html`, and for `BrowserRouter basename={process.env.PUBLIC_URL}`
if the app sets that up) from the `homepage` field in `package.json`. Update
it to the new custom domain:

```json
"homepage": "https://<slug>.jyjwong.com/"
```

(Setting it to `"https://old.jyjulianwong.github.io/Repo-Name/"` is the
pattern you're replacing — CRA also accepts a bare `"/"` or `"."`, but
matching the existing convention of a full URL here keeps `homepage` useful
as a human-readable link too, e.g. shown on npm or in `package.json`
tooling.)

`public/index.html`'s standard CRA scaffold already uses `%PUBLIC_URL%/...`
placeholders for every asset reference — these resolve correctly once
`homepage` is fixed, no direct edit needed. Only hand-written absolute paths
added later (not using the placeholder) would need a manual check.

## Deploy mechanism varies — check before assuming

CRA repos onboarded before this skill existed were deployed a few different
ways — a GitHub Actions workflow that runs `npm run build` and pushes
`build/` via `JamesIves/github-pages-deploy-action` to a `gh-pages` branch,
or the `gh-pages` npm package's own `predeploy`/`deploy` scripts run by
hand. Either way, the CNAME file travels through `public/` → `build/`
automatically, so the fix above is the same regardless of which deploy
mechanism this particular repo uses. Just don't assume a workflow exists —
check `.github/workflows/` and `package.json`'s `scripts` block before
writing the PR description's "what happens on merge" explanation.

## Self-referential links

Same as every other variant: `grep` tracked files for
`https://jyjulianwong.github.io/<repo-name>` and replace with
`https://<slug>.jyjwong.com/`.

## Still run the explicit API step

CRA repos deployed via `JamesIves/github-pages-deploy-action` or the
`gh-pages` npm package are normally "legacy" (branch-based) Pages, where
the CNAME file alone *does* correctly auto-configure the custom domain —
but `SKILL.md` step 5 (`scripts/set_pages_cname.sh`) still runs
unconditionally for every variant, not just the ones where it's load-bearing.
On a legacy site it's a harmless no-op confirmation, not a conflicting
write — see `references/custom-domain-api.md`. Don't skip it just because
this variant usually doesn't need it.
