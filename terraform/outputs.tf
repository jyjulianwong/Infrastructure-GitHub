output "ruleset_ids" {
  description = "Created ruleset ID per repository"
  value       = { for repo, mod in module.branch_ruleset : repo => mod.ruleset_id }
}
