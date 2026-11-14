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

`terraform/branch_ruleset.tf` discovers repositories live on every `plan`/`apply`
via a `data "github_repositories"` query (GitHub's search API,
`query = "user:${var.github_owner} archived:false fork:false"`) and applies the
module to every result — not a hardcoded list. A repo you create later is picked up
automatically on the next apply; one you archive drops out automatically. No
Terraform code change needed either way. (This does mean a plan can show a repo
being added/removed purely because you created or archived something on GitHub —
not because anyone edited this repo.)

Repos that don't match that query but should still be protected go in
`var.branch_ruleset_additional_repositories` (`terraform/variables.tf`) — e.g.
`TradingAgents-Funds`, a fork, which the query's `fork:false` deliberately excludes.
Edit that list to add more overrides later.

This discovery query and override list are scoped to the `branch_ruleset` module
only — each file name and variable is prefixed `branch_ruleset_*` deliberately. A
future module (e.g. GitHub Pages config) that needs a different repo filter gets
its own `<module>.tf` file with its own discovery query and its own
`<module>_additional_repositories` variable, rather than sharing these.

- **`pages_domains.tf`** — one Cloudflare `CNAME` DNS record per repository in
  `var.pages_domain_repositories` (`terraform/variables.tf`), in the
  `var.pages_domain_zone` zone (`jyjwong.com`), pointing at
  `jyjulianwong.github.io`. This is a hand-maintained map, not a live discovery
  query like `branch_ruleset`'s — not every repository has, or should have,
  Pages enabled. It only manages the DNS side: the matching GitHub Pages
  `cname` setting is configured implicitly when each listed repository commits
  a `CNAME` file to its own Pages publishing source (done via that repo's own
  PR, not here) — see the comment at the top of `pages_domains.tf` for why.

## Repository layout

```
terraform/
├── bootstrap/          # one-time: AWS S3 state bucket + DynamoDB lock table + CI IAM user
├── backend.tf           # S3 backend (bucket/dynamodb_table passed via -backend-config)
├── main.tf              # shared: terraform block + github + cloudflare providers only
├── branch_ruleset.tf    # branch_ruleset module's own repo discovery + module calls + outputs
├── pages_domains.tf     # pages_domains module's own Cloudflare DNS records
├── variables.tf         # github_owner, branch_ruleset_additional_repositories, pages_domain_*
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
read/write on every repo owned by `github_owner` — the default per-workflow
`GITHUB_TOKEN` can't manage rulesets on repos other than the one the workflow runs
in. [Create one here](https://github.com/settings/tokens/new), then copy it — you
won't be able to view it again.

### 4. Create a Cloudflare API token

Scoped to `Zone → DNS → Edit`, restricted to the `jyjwong.com` zone — nothing
broader is needed for `pages_domains.tf`.
[Create one here](https://dash.cloudflare.com/profile/api-tokens), using the
"Edit zone DNS" template, then copy it.

### 5. Add GitHub Actions secrets

In this repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `AWS_ACCOUNT_ID` | `$AWS_ACCOUNT_ID` from step 1 (`echo $AWS_ACCOUNT_ID`) |
| `AWS_ACCESS_KEY_ID` | From step 2 |
| `AWS_SECRET_ACCESS_KEY` | From step 2 |
| `GITHUB_ADMIN_TOKEN` | From step 3 |
| `CLOUDFLARE_API_TOKEN` | From step 4 |

Or, with the [`gh` CLI](https://cli.github.com/) (no manual copy-paste — run from
`terraform/bootstrap`, with `GITHUB_ADMIN_TOKEN` from step 3 and `CLOUDFLARE_API_TOKEN`
from step 4 exported first):

```bash
gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID"
gh secret set AWS_ACCESS_KEY_ID --body "$(terraform output -raw github_actions_access_key_id)"
gh secret set AWS_SECRET_ACCESS_KEY --body "$(terraform output -raw github_actions_secret_access_key)"
gh secret set GITHUB_ADMIN_TOKEN --body "$GITHUB_ADMIN_TOKEN"
gh secret set CLOUDFLARE_API_TOKEN --body "$CLOUDFLARE_API_TOKEN"
```

## Applying locally

```bash
export GITHUB_TOKEN=$(gh auth token)   # or a PAT with `repo` scope
export CLOUDFLARE_API_TOKEN=...        # Zone:DNS:Edit on jyjwong.com
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
