variable "repository" {
  description = "Name of the repository (under the provider's configured owner) to apply the default-branch ruleset to"
  type        = string
}

variable "required_approving_review_count" {
  description = "Number of approving reviews required before a PR can merge (0 = a PR is required, but no mandatory approval count)"
  type        = number
  default     = 0
}

variable "require_code_owner_review" {
  description = "Require an approving review from a code owner before a PR can merge"
  type        = bool
  default     = false
}
