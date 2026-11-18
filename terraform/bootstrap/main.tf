terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend block here: scripts/bootstrap.sh applies this with local state
  # on the first run (the state bucket doesn't exist yet), then migrates the
  # state into that bucket via a generated _backend.tf (gitignored).
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID to deploy into — Terraform will refuse to apply if the active credentials resolve to a different account"
  type        = string
}

variable "github_repository" {
  description = "owner/name of the GitHub repository whose Actions workflows may assume the CI role"
  type        = string
  default     = "jyjulianwong/Infrastructure-GitHub"
}

variable "project" {
  description = "Short project identifier used to namespace resource names"
  type        = string
  default     = "jyjulianwong-iacgh"
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

locals {
  global_prefix = "${var.aws_account_id}-${var.project}" # S3 bucket (globally scoped)
  scoped_prefix = var.project                            # DynamoDB table, IAM role (account-scoped)
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "${local.global_prefix}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "${local.scoped_prefix}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider — ACCOUNT-WIDE SINGLETON.
#
# An AWS account can hold only one OIDC provider per issuer URL, so this repo
# owns it for every jyjulianwong-* repo deploying into the account. The other
# repos' bootstraps look it up with a data source and refuse to run until this
# bootstrap has been applied. Never destroy this stack while they still
# deploy into the account.
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# IAM — GitHub Actions role (OIDC), scoped to Terraform state access only.
#
# Unlike the other jyjulianwong-* repos' github-actions roles, this one needs
# no broader "TerraformApplyRegional"/"TerraformApplyIAM" grant — the main
# stack's resources (github_repository_ruleset, Cloudflare DNS records) are
# GitHub/Cloudflare API objects, not AWS resources, so there's nothing else
# for this role to touch. The actual apply is authorized separately, by a
# GitHub PAT and a Cloudflare API token (see ../README.md and
# .github/workflows/deploy-terraform.yml).
#
# Lives here, not in the main stack, so CI can never rewrite its own trust
# policy or permissions — only a local bootstrap apply can.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pushes to main (apply) and pull requests (plan) only.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.scoped_prefix}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.tf_lock.arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.scoped_prefix}-github-actions-role-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}

output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  value = aws_dynamodb_table.tf_lock.name
}

output "github_actions_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC — stored as GitHub secret AWS_ROLE_ARN by scripts/bootstrap.sh"
  value       = aws_iam_role.github_actions.arn
}
