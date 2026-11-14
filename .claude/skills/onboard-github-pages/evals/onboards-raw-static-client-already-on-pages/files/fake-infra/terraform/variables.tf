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

variable "pages_domain_zone" {
  description = "Cloudflare zone that GitHub Pages custom-domain CNAME records are created in. Scoped to the pages_domains module only."
  type        = string
  default     = "jyjwong.com"
}

variable "pages_domain_repositories" {
  description = "Repositories with a GitHub Pages site, mapped to the subdomain label (no zone suffix) each one is reachable at under var.pages_domain_zone — e.g. \"market-regime-detector\" for market-regime-detector.jyjwong.com. Scoped to the pages_domains module only; unlike branch_ruleset.tf, this is a hand-maintained list rather than a live discovery query, because not every repository has (or should have) Pages enabled. Each repository listed here must also carry a matching CNAME file in its own Pages publishing source (see that repo's PR) — this variable only creates the DNS side."
  type        = map(string)
  default = {
    "Anon-OpenRouter-Chat" = "anon-openrouter-chat"
    "LasagnaStack"         = "lasagnastack"
  }
}
