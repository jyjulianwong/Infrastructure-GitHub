terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Auth comes from the GITHUB_TOKEN environment variable (a personal access
# token with `repo` scope — repository rulesets are managed per-repo, so an
# org-level token/app is not needed). No `token` argument here: local runs
# export it from `gh auth token`, CI reads it from a repo secret (see
# .github/workflows/deploy-terraform.yml).
provider "github" {
  owner = var.github_owner
}

# Auth comes from the CLOUDFLARE_API_TOKEN environment variable (a token
# scoped to Zone:DNS:Edit on the jyjwong.com zone — nothing broader is
# needed). No `api_token` argument here, for the same reason the github
# provider above takes none: local runs export it by hand, CI reads it from
# a repo secret (see .github/workflows/deploy-terraform.yml).
provider "cloudflare" {}
