output "ruleset_id" {
  description = "The created ruleset's numeric ID"
  value       = github_repository_ruleset.main_protected.ruleset_id
}

output "ruleset_node_id" {
  description = "The created ruleset's GraphQL node ID"
  value       = github_repository_ruleset.main_protected.node_id
}
