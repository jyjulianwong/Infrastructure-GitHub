terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
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
