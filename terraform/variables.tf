variable "github_owner" {
  description = "GitHub user/org that owns the repositories this stack manages"
  type        = string
  default     = "jyjulianwong"
}

variable "branch_ruleset_additional_repositories" {
  description = "Repositories to protect even though they don't match branch_ruleset.tf's live discovery query (e.g. forks, which are excluded by fork:false) — merged with the discovered set. Scoped to the branch_ruleset module only; a future module's override list should be its own separate variable."
  type        = list(string)
  default     = ["TradingAgents-Funds"]
}
