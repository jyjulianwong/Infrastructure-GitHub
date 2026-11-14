# ---------------------------------------------------------------------------
# Cloudflare DNS for GitHub Pages custom domains — scoped to this module
# only, same convention as branch_ruleset.tf. This file owns the DNS side
# (one CNAME record per repository, in the jyjwong.com zone, pointing at
# jyjulianwong.github.io). It deliberately does NOT manage the GitHub side
# (the repository's Pages `cname` setting): that's set implicitly when a
# matching CNAME file is committed to the repo's Pages publishing source
# (GitHub detects it on the next Pages build and both configures the custom
# domain and redirects the old jyjulianwong.github.io/<repo>/ URL to it) —
# each repository in var.pages_domain_repositories gets that file added via
# its own PR, not via Terraform, to avoid having to import every one of
# those repositories' full github_repository resource into this state just
# to reach their `pages` block.
#
# jyjulianwong (the account's github.io user site) was migrated to
# jyjwong.com before this module existed, by that same CNAME-file-only
# method with no Terraform involved — it is not part of
# var.pages_domain_repositories and this file does not touch its DNS.
# ---------------------------------------------------------------------------

data "cloudflare_zone" "pages_domain" {
  filter = {
    name = var.pages_domain_zone
  }
}

# unproxied (grey-cloud), mirroring the existing jyjwong.com apex record:
# GitHub Pages serves its own TLS certificate for the custom domain, and
# proxying would put Cloudflare's in front of it instead.
resource "cloudflare_dns_record" "pages_domain" {
  for_each = var.pages_domain_repositories

  zone_id = data.cloudflare_zone.pages_domain.zone_id
  name    = each.value
  type    = "CNAME"
  content = "jyjulianwong.github.io"
  ttl     = 1 # "Automatic"
  proxied = false
  comment = "GitHub Pages custom domain for jyjulianwong/${each.key}"
}
