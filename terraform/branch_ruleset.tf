# ---------------------------------------------------------------------------
# Repository discovery for the branch_ruleset module ONLY. A future module
# (e.g. GitHub Pages config) may need a completely different filter/query —
# it should define its own data source and its own additional-repos
# variable, not reuse these. Don't generalize this into a shared, stack-wide
# repo list.
#
# Queried live from GitHub's search API on every plan/apply, not a hardcoded
# list: a repo created after this stack exists gets picked up automatically
# (next apply), and one that's archived drops out automatically, without
# editing this file. "user:" matches repos owned by a personal account;
# switch to "org:" if github_owner ever points at an organization instead.
# ---------------------------------------------------------------------------

data "github_repositories" "branch_ruleset_candidates" {
  query = "user:${var.github_owner} archived:false fork:false"
}

# ---------------------------------------------------------------------------
# Branch protection — one ruleset per repository found above, plus whatever's
# explicitly opted in via var.branch_ruleset_additional_repositories (repos
# the discovery query above deliberately excludes, e.g. forks), protecting
# each repo's default branch (brief: "main is protected, no one can push
# directly except repository admins").
# ---------------------------------------------------------------------------

module "branch_ruleset" {
  source = "./modules/branch_ruleset"
  for_each = toset(concat(
    data.github_repositories.branch_ruleset_candidates.names,
    var.branch_ruleset_additional_repositories,
  ))

  repository = each.value
}

output "branch_ruleset_ids" {
  description = "Created ruleset ID per repository"
  value       = { for repo, mod in module.branch_ruleset : repo => mod.ruleset_id }
}
