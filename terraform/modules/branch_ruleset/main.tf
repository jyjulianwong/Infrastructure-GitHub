terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

locals {
  # GitHub's REST/Terraform docs never publish these numeric built-in
  # RepositoryRole IDs anywhere — confirmed empirically against two
  # independent, widely-used community modules (trussworks/terraform-github-repository,
  # cloudposse/terraform-github-repository), which agree: Maintain=2,
  # Write=4, Admin=5. Only Admin is used here.
  repository_role_admin = 5
}

resource "github_repository_ruleset" "main_protected" {
  name        = "protect-default-branch"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      # "~DEFAULT_BRANCH" rather than a literal "refs/heads/main" — covers
      # every repo's actual default branch (main for most, master for a
      # couple of older ones) without per-repo branch-name configuration.
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Repository admins (including the owner) can still push directly,
  # force-push, or delete the branch; everyone else must go through a pull
  # request — this is the one bypass this module grants.
  bypass_actors {
    actor_id    = local.repository_role_admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = var.required_approving_review_count
      require_code_owner_review         = var.require_code_owner_review
      require_last_push_approval        = false
      dismiss_stale_reviews_on_push     = false
      required_review_thread_resolution = false
    }
  }
}
