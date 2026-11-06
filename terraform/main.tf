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

# ---------------------------------------------------------------------------
# Branch protection — one ruleset per repository in var.repositories,
# protecting each repo's default branch (brief: "main is protected, no one
# can push directly except repository admins").
# ---------------------------------------------------------------------------

module "branch_ruleset" {
  source   = "./modules/branch_ruleset"
  for_each = toset(var.repositories)

  repository = each.value
}
