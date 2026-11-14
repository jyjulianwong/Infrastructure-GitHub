# Variant: raw-static

Detected when there's a directory of hand-written static files (typically
`client/`) with no build tool in front of it — the deploy workflow publishes
that directory's contents directly, usually via
`peaceiris/actions-gh-pages` (`publish_dir:`) or
`JamesIves/github-pages-deploy-action` (`folder:`), to a `gh-pages` branch.
`detect_build_tool.py` reports `publish_dir`.

## CNAME placement

Add `<publish_dir>/CNAME` (e.g. `client/CNAME`) containing exactly the
subdomain. Whatever the deploy workflow publishes, it publishes wholesale —
no copy-plugin step to register, unlike the `webpack-copy` variant.

## Base path fix

**Check first — there's a good chance there isn't one.** A hand-written
static site has no bundler rewriting asset URLs at build time, so whether
it needs a fix depends entirely on how its own HTML/CSS/JS reference
assets:

- **Relative paths** (`href="favicon.ico"`, `src="style.css"`, no leading
  `/`) — already root-independent, nothing to fix. This has been the common
  case in practice (the repos with this build pattern wrote their assets
  this way from the start, since they were never built against a subpath to
  begin with).
- **Root-absolute paths** (`href="/favicon.ico"`) — these resolved against
  `jyjulianwong.github.io/<repo-name>/favicon.ico` before (GitHub Pages
  itself handles the project-subpath rewriting for root-absolute refs on a
  `*.github.io/<repo>/` URL), and will resolve against the domain root
  correctly after the move with **no edit needed either** — the custom
  domain's root *is* the site's actual root now, so a root-absolute
  reference just works. The case this bites you is the opposite: a
  **hardcoded full URL** like `https://jyjulianwong.github.io/Repo-Name/foo.js`
  — that one needs a literal find-and-replace, see below.

So: grep for hardcoded `jyjulianwong.github.io/<repo-name>` first; if there
are none, there's genuinely nothing else to change for this variant beyond
the CNAME file.

## Self-referential links

`grep` every HTML/JS/MD file under `publish_dir` plus `README.md` for
`https://jyjulianwong.github.io/<repo-name>` and replace with
`https://<slug>.jyjwong.com/`. This has mattered in practice for links
*between* sibling repos in this account (one project's static client
linking to another project's docs site) — check whether any such link
exists before assuming it's just cosmetic.

## Still run the explicit API step

Raw-static repos deployed via `peaceiris/actions-gh-pages` are normally
"legacy" (branch-based) Pages, where the CNAME file alone *does* correctly
auto-configure the custom domain — but `SKILL.md` step 5
(`scripts/set_pages_cname.sh`) still runs unconditionally for every
variant, not just the ones where it's load-bearing. On a legacy site it's
a harmless no-op confirmation, not a conflicting write — see
`references/custom-domain-api.md`. Don't skip it just because this variant
usually doesn't need it.

## Also check: backend CORS

These static clients are often a thin frontend over a separately-deployed
backend (Lambda, Render, etc.) that restricts CORS to an exact origin via
an env var or Terraform variable (commonly named something like
`CLIENT_GITHUB_PAGES_ORIGIN`, `CORS_ALLOWED_ORIGINS`, or similar — check
that backend's own repo/`variables.tf`/`main.py` for the exact name rather
than guessing). If found, flag it in the PR body as a manual follow-up with
the exact variable name and the new value it needs
(`https://<slug>.jyjwong.com`) — this lives in a deployed secret/env var,
not in this PR's diff, so you can describe it but can't fix it here.
