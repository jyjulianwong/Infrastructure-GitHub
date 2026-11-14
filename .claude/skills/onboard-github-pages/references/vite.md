# Variant: vite

Detected when `vite.config.{js,ts,mjs}` exists at the repo root or in a
subdirectory (e.g. `frontend/vite.config.js`). `detect_build_tool.py` reports
`vite_config_path`, `base_line` (the current `base:` setting, if any),
and `public_dir`.

## CNAME placement

Vite copies everything in its `publicDir` (default `public/`, relative to
the vite config's own directory — so `frontend/public/` if the config is
`frontend/vite.config.js`) straight into the build output. Add:

```
<dir of vite config>/public/CNAME
```

containing exactly the subdomain, e.g. `anon-openrouter-chat.jyjwong.com`
(one line, trailing newline, nothing else — this is a plain GitHub Pages
convention, not a Vite-specific format).

If there's no `public/` directory yet, check `vite.config`'s `publicDir`
option before assuming the default — don't create a `public/` dir that Vite
won't actually pick up.

## Base path fix

The custom domain serves from the root, not from a `/<repo-name>/` subpath,
so the Vite `base` option must become `/`. Three cases, in the order you'll
actually encounter them:

1. **Hardcoded to the repo name** (`base: '/Repo-Name/'`) — the common case.
   Change it to `base: '/'` directly.

2. **Driven by a plain workflow-level env var** (e.g.
   `base: process.env.VITE_BASE_PATH ?? '/'` in vite.config, with
   `VITE_BASE_PATH: /${{ github.event.repository.name }}/` set in the
   deploy workflow's `env:` block). Delete that env line from the workflow
   — the vite.config's own fallback (`'/'`) then applies. Don't touch
   vite.config itself; it's already correct.

3. **Driven by a GitHub Actions *secret*** (e.g.
   `env: { VITE_CLIENT_BASE_PATH: ${{ secrets.VITE_CLIENT_BASE_PATH }} }`).
   You cannot read or change a secret's value from inside the repo. Still
   add the CNAME file, but flag this explicitly in the PR body as a
   required manual follow-up: the user must clear or delete that secret
   themselves, or the build keeps using the old subpath regardless of what
   this PR changes. Say which secret, by name, and what to set it to
   (usually: delete it, or set it to empty, so the vite.config fallback
   takes over).

## Things that are usually already fine (verify, don't blindly "fix")

- `<link href="/favicon.ico">`-style **root-absolute** references in
  `index.html` — Vite rewrites these according to `base` at build time, so
  once `base` is `/` these resolve correctly with no edit needed.
- `%BASE_URL%favicon.ico`-style placeholders — same thing, Vite substitutes
  the real base automatically.
- A hardcoded `<script type="module" src="/src/main.tsx">` — Vite always
  rewrites this to the real hashed asset path at build time regardless of
  `base`; never edit it.

## Self-referential links

`grep` the repo (README.md, index.html meta tags like `og:url`/`twitter:url`,
any other markdown/HTML) for `https://jyjulianwong.github.io/<repo-name>` or
a bare placeholder like `https://yourdomain.com/` and replace with
`https://<slug>.jyjwong.com/`. These are safe to edit directly — they're
tracked source, not secrets.

## Don't stop at the CNAME file

Vite apps deployed via `actions/deploy-pages` are normally the "workflow"
Pages build type, where the CNAME file alone does **not** configure the
custom domain — see `references/custom-domain-api.md` and `SKILL.md`
step 5. Run `scripts/set_pages_cname.sh` regardless; don't assume the file
was enough just because it's the right file in the right place.
