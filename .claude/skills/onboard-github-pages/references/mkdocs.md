# Variant: mkdocs

Detected when `mkdocs.yml` exists at the repo root. `detect_build_tool.py`
reports `docs_dir` (from `docs_dir:` in mkdocs.yml, default `docs`) and
whether `site_url:` is already set.

## CNAME placement

mkdocs copies **any non-Markdown file** found under `docs_dir` straight into
the built `site/` output, preserving its relative path — this is how a
`CNAME` file (which has no `.md` extension and isn't itself a page) ends up
at the root of the deployed site. Add:

```
<docs_dir>/CNAME
```

containing exactly the subdomain, e.g. `turtle-quant-1.jyjwong.com`. This is
true regardless of how the built `site/` directory then gets to GitHub
Pages — whether that's `actions/upload-pages-artifact` + `actions/deploy-pages`
(the "workflow" Pages build type, seen on every mkdocs repo migrated so
far) or a legacy branch-based deploy. The CNAME file rides along inside
`site/` either way.

## Base path fix

**There usually isn't one.** mkdocs has no equivalent of Vite's `base` or
CRA's `homepage` — a built site's internal links are either relative
already (mkdocs-material's default) or governed by `site_url`, which
affects the generated `sitemap.xml`/canonical `<link>` tags but not whether
the site actually renders correctly at a new root. Don't go looking for a
base-path setting to fix here; there usually isn't one, and "fixing" one
that doesn't exist wastes a turn establishing that fact that this note
already tells you.

Do still update `site_url:` in `mkdocs.yml` if it's present, to
`https://<slug>.jyjwong.com/` — it's not required for the site to work, but
it's what feeds the sitemap/canonical tags search engines see, and it's
cheap to get right while you're already in this file for the CNAME-adjacent
check.

## Self-referential links

mkdocs/docs-site repos tend to link to themselves a lot (README badges,
"read the docs at ..." lines, cross-links between sibling projects in this
same account). `grep` `README.md` and every file under `docs_dir` for
`https://jyjulianwong.github.io/<repo-name>` and replace with
`https://<slug>.jyjwong.com/`.

**Also check other repos in this account that might link to *this* repo's
docs site** — e.g. `Investment-News-Analysis-AI`'s client links to
`Obsidian-Server`'s docs. If you know of (or can quickly find via a repo
search) another sibling repo linking to the one you're onboarding, flag it
in the PR body as a courtesy follow-up — fixing it is a tiny edit on that
other repo's own PR the next time it's touched, not blocking this one.

## Don't stop at the CNAME file

mkdocs sites deployed via `actions/deploy-pages` are normally the
"workflow" Pages build type, where the CNAME file alone does **not**
configure the custom domain — confirmed on `Obsidian-Server` itself: the
file reached the deployed artifact correctly and the site still 404'd on
the custom domain until an explicit API call was made. See
`references/custom-domain-api.md` and `SKILL.md` step 5. Run
`scripts/set_pages_cname.sh` regardless of how clean the mkdocs build
looks.
