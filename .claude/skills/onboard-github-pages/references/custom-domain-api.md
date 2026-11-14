# The CNAME file alone is not enough for "workflow" build-type sites

Discovered live on 2026-11-14, after the first real batch of onboardings
(9 repos) seemed to go cleanly — every PR merged, every DNS record
resolved, and yet several of the sites served a plain GitHub 404 ("There
isn't a GitHub Pages site here") when visited at the new custom domain,
over HTTP only (no HTTPS at all). The actual mechanism behind every single
instance of this turned out to be the same, confirmed by directly reading
`gh api repos/<owner>/<repo>/pages`: `"cname": null`.

## The split, confirmed empirically

GitHub Pages has two build types, and they behave differently here —
this isn't documented anywhere obvious, it was reverse-engineered from
what actually happened across real repos:

- **`legacy`** (branch-based: `peaceiris/actions-gh-pages`,
  `JamesIves/github-pages-deploy-action`, the `gh-pages` npm package) —
  committing a `CNAME` file to the published branch **does** auto-configure
  the custom domain. Confirmed working with no extra step on
  `Investment-News-Analysis-AI` and `Market-Regime-Detector` (both
  `raw-static`/`cra`-style variants).

- **`workflow`** (Actions-based: `actions/deploy-pages` after
  `actions/upload-pages-artifact`) — committing a `CNAME` file into the
  deployed artifact does **nothing** for the custom domain setting. It was
  directly confirmed in the artifact (`tar -cvf` logs showed `./CNAME`
  present, with the right content, in a successful deploy), and the
  `cname` field was still `null` afterward. This is the build type the
  `vite`, `mkdocs`, and `webpack-copy` variants normally produce — i.e.
  most of what this skill handles.

## The fix

One explicit API call, after Pages is enabled (regardless of whether a
deploy has happened yet — this sets Pages' own site record, independent of
deployed content):

```bash
bash scripts/set_pages_cname.sh <owner>/<repo> <slug>.jyjwong.com
```

This is **step 4.5** in `SKILL.md`'s procedure — always run it, for every
variant, regardless of build type. On a `legacy` site it's a harmless
no-op confirmation (the value's already right); on a `workflow` site it's
the thing that actually makes the site reachable. There's no reliable way
to predict build type from the variant alone without checking (a `vite`
app *could* theoretically be deployed via a legacy branch workflow), so
don't try to skip this call based on which variant was detected — just
always run it.

## One open question, deliberately left open

Whether a *future* `workflow`-build-type deploy whose artifact lacks a
CNAME file would ever clear a `cname` already set via this API call is
untested — there's no confirmed evidence either way. Given that
uncertainty, keep doing *both*: commit the CNAME file (cheap insurance,
and it's still the right thing to have in the published output on general
principle) *and* always make this explicit API call. Don't drop the file
just because the API call is now known to be the thing that actually
matters.

## What this looked like from the outside, for debugging next time

- `dig <domain>` resolves correctly to `jyjulianwong.github.io.` / GitHub's
  Pages IPs — DNS is not the problem.
- `curl -I http://<domain>` returns a GitHub 404 page (`Server: GitHub.com`,
  body says "There isn't a GitHub Pages site here") — not a connection
  failure, not a DNS failure. This exact combination (DNS fine, GitHub
  itself says no site exists for this hostname) is the signature of
  `cname: null` on the target repo.
- HTTPS doesn't work at all until the custom domain is set and GitHub
  issues a certificate for it — expect HTTP-only immediately after fixing
  this, with `https_enforced: false` and `https_certificate.state` moving
  from absent to `"approved"` over the following minutes.
- After fixing it, GitHub's own CDN (Fastly) may still serve a *stale
  cached* 404 for a few minutes from whichever edge node already cached
  the pre-fix response — `curl -I` showing `X-Cache: HIT` with a climbing
  `Age:` header on an otherwise-correct domain means wait, not re-debug.
  There's no client-triggerable way to bust this cache.
