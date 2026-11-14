# Variant: webpack-copy

Detected when a webpack config (commonly `config/webpack.common.js`) uses
`CopyPlugin`/`copy-webpack-plugin` to assemble the output directory, and
there's no `public/` folder for a framework CLI to copy automatically —
static assets instead live loose inside `src/` (or wherever `entry_dir`
points) and get listed one-by-one in the plugin's `patterns` array.
`detect_build_tool.py` reports `webpack_config_path`, `entry_dir`, and
`basename_env_var` (the env var name feeding a router's `basename`, if any).

## CNAME placement

There's no folder webpack copies *wholesale* the way Vite/CRA do — every
static file in the output has to be named explicitly in `CopyPlugin`'s
`patterns` list, or it won't be in `dist/`. Two edits, not one:

1. Add `<entry_dir>/CNAME` (e.g. `src/CNAME`) containing exactly the
   subdomain.
2. Add a matching entry to the `CopyPlugin` patterns array in the webpack
   config, next to the other loose static assets (favicon, manifest, etc.)
   that are already copied the same way:

   ```js
   new CopyPlugin({
     patterns: [
       // ...existing entries...
       { from: path.resolve(__dirname, "../src/CNAME") },
     ],
   }),
   ```

   Skipping step 2 is the easy mistake here — the file would sit in `src/`
   forever and never reach `dist/`, so GitHub Pages would never see it.

## Base path fix

Look for an env var threaded through `DefinePlugin`/`EnvironmentPlugin`
whose name contains `BASENAME` (reported as `basename_env_var`), feeding a
router's `basename` prop (e.g.
`<BrowserRouter basename={process.env.ROUTER_BASENAME || ""}>`). If the
deploy workflow sets it to the repo name (e.g.
`ROUTER_BASENAME: /Repo-Name` in the build step's `env:` block), delete that
line — the webpack config's own default for that var is already `null`,
which the router's `|| ""` fallback turns into an empty (root-relative)
basename. Don't edit the webpack config or the component itself; the
default was already correct, only the workflow override was wrong.

## Also check: is anything else origin-locked?

Repos built this way have sometimes been seen calling an external API
directly from the browser (not through this repo's own backend) — e.g. an
S3 bucket's REST API. If so, that external resource's own CORS
configuration (not anything in this repo) will be checking the browser's
`Origin` header against the *old* `jyjulianwong.github.io` origin, and will
start rejecting requests once the custom domain goes live. Grep the repo
(README, `.env.example`, any infra-as-code) for that old origin string; if
found, flag the specific resource and its new required origin
(`https://<slug>.jyjwong.com`) in the PR body as a manual follow-up — you
can't edit a live AWS console setting from inside a git PR.

## Self-referential links

Same pattern as every other variant: `grep` tracked files (README, any
example JSON config blocks) for `https://jyjulianwong.github.io/<repo-name>`
and replace with `https://<slug>.jyjwong.com/`.

## Don't stop at the CNAME file

webpack apps deployed via `actions/deploy-pages` are normally the
"workflow" Pages build type, where the CNAME file alone does **not**
configure the custom domain — see `references/custom-domain-api.md` and
`SKILL.md` step 5. Registering the file in `CopyPlugin`'s patterns gets it
into `dist/`, but that's necessary, not sufficient — still run
`scripts/set_pages_cname.sh`.
