# Infrastructure-GitHub

Terraform that manages infrastructure-as-code settings across `jyjulianwong`'s GitHub
repositories. The state backend follows the same AWS S3 + DynamoDB pattern used across
this account's other Terraform projects (e.g. `Market-Regime-Detector`,
`Investment-News-Analysis-AI`) — only the thing being managed (GitHub, not AWS
resources) differs.

## What this manages

- **`branch_ruleset` module** (`terraform/modules/branch_ruleset/`) — one
  `github_repository_ruleset` per repository, applied to each repo's default branch:
  - Direct pushes, force-pushes, and branch deletion are blocked.
  - Changes must land via a pull request.
  - Repository admins (including the owner) can still push/force-push/delete directly
    — the one bypass actor granted (`RepositoryRole` id `5`, GitHub's built-in Admin
    role; see the module's `main.tf` comment for how that undocumented ID was
    confirmed).

The root stack (`terraform/main.tf`) applies this module to every repository listed in
`var.repositories` (`terraform/variables.tf`).

## Repository layout

```
terraform/
├── bootstrap/        # one-time: AWS S3 state bucket + DynamoDB lock table + CI IAM user
├── backend.tf         # S3 backend (bucket/dynamodb_table passed via -backend-config)
├── main.tf            # github provider + branch_ruleset module, applied per repository
├── variables.tf       # github_owner, repositories list
├── outputs.tf
└── modules/
    └── branch_ruleset/
```

## One-time setup

### 1. Bootstrap the state backend

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply -var="aws_account_id=$AWS_ACCOUNT_ID"
```

### 2. Retrieve the generated IAM credentials

```bash
cd terraform/bootstrap
terraform output github_actions_access_key_id
terraform output -raw github_actions_secret_access_key && echo
cd ../..
```

### 3. Create a GitHub personal access token

With `repo` scope (classic), or a fine-grained token with "Administration"
read/write on every repo listed in `var.repositories` — the default per-workflow
`GITHUB_TOKEN` can't manage rulesets on repos other than the one the workflow runs
in. [Create one here](https://github.com/settings/tokens/new), then copy it — you
won't be able to view it again.

### 4. Add GitHub Actions secrets

In this repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `AWS_ACCOUNT_ID` | `$AWS_ACCOUNT_ID` from step 1 (`echo $AWS_ACCOUNT_ID`) |
| `AWS_ACCESS_KEY_ID` | From step 2 |
| `AWS_SECRET_ACCESS_KEY` | From step 2 |
| `GH_ADMIN_TOKEN` | From step 3 |

Or, with the [`gh` CLI](https://cli.github.com/) (no manual copy-paste — run from
`terraform/bootstrap`, with `GH_ADMIN_TOKEN` from step 3 exported first):

```bash
gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID"
gh secret set AWS_ACCESS_KEY_ID --body "$(terraform output -raw github_actions_access_key_id)"
gh secret set AWS_SECRET_ACCESS_KEY --body "$(terraform output -raw github_actions_secret_access_key)"
gh secret set GH_ADMIN_TOKEN --body "$GH_ADMIN_TOKEN"
```

## Applying locally

```bash
export GITHUB_TOKEN=$(gh auth token)   # or a PAT with `repo` scope
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

terraform -chdir=terraform init \
  -backend-config="bucket=${AWS_ACCOUNT_ID}-jyjulianwong-iacgh-terraform-state" \
  -backend-config="dynamodb_table=jyjulianwong-iacgh-terraform-lock"
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

## CI/CD

`.github/workflows/deploy-terraform.yml`: `terraform plan` is posted as a PR comment
on pull requests touching `terraform/**`; `terraform apply` runs on merge to `main`.
