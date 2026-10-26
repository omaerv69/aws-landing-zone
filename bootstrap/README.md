# Bootstrap

Creates, in the management account, the resources every other stack depends on:

- an S3 bucket that stores every Terraform state of the landing zone: versioned, encrypted, TLS only, public access blocked, protected by `prevent_destroy`;
- an IAM OIDC identity provider that trusts GitHub Actions;
- two IAM roles for CI: `lz-github-plan` (read-only, from pull requests and `main`) and `lz-github-apply` (administrator, from the protected `production` environment only).

This is the only stack applied from a workstation, and it is never destroyed: removing it would orphan every other state.

## Prerequisites

1. The manual steps of phase 0 are done: management account created and secured (root MFA, alternate contacts), budget alerts in place, AWS Organizations and IAM Identity Center enabled.

2. Tools installed:

   | Tool | Version | Used for |
   |---|---|---|
   | Terraform | the one in `/.terraform-version` | everything |
   | AWS CLI | v2 | IAM Identity Center sign-in |
   | pre-commit | latest | checks before each commit |
   | TFLint, terraform-docs, Checkov | latest | called by pre-commit |

   Then, once per clone, from the repository root:

   ```bash
   pre-commit install
   pre-commit autoupdate   # pins every hook to its latest release
   ```

3. An AWS CLI profile that signs in through IAM Identity Center:

   ```bash
   aws configure sso --profile lz-management   # SSO region: eu-west-3
   aws sso login --profile lz-management
   export AWS_PROFILE=lz-management
   aws sts get-caller-identity                 # must show the management account
   ```

4. The repository identity set in `config/landing-zone.yaml`: `github.owner` with the exact case used on GitHub, plus the numeric `owner_id` and `repository_id`. GitHub embeds both IDs in the OIDC subject claim of every repository created after 2026-07-15:

   ```bash
   gh api repos/<owner>/aws-landing-zone --jq '.owner.id, .id'
   # or, without the GitHub CLI:
   curl -s https://api.github.com/repos/<owner>/aws-landing-zone | jq '.owner.id, .id'
   ```

   Terraform refuses to plan while these values are missing.

## First apply

```bash
cd bootstrap
terraform init
terraform providers lock \
  -platform=linux_amd64 -platform=darwin_arm64 \
  -platform=darwin_amd64 -platform=windows_amd64
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

`terraform providers lock` records provider checksums for every platform, so the lock file works both on your machine and on the Linux runners of GitHub Actions. The plan must announce 13 resources to add, and nothing to change or destroy.

## Move the state into the bucket

The stack starts with a local state because the bucket does not exist yet. Once it exists, move the state into it:

```bash
BUCKET=$(terraform output -raw state_bucket)
cp backend.tf.example backend.tf
terraform init -migrate-state -backend-config="bucket=${BUCKET}"
terraform plan                                  # must report: No changes
rm -f terraform.tfstate terraform.tfstate.backup
```

The bucket name contains the account ID, so it stays out of the public repository and is passed at init time. To avoid typing it again, write `bucket = "<name>"` in a `backend.hcl` file (ignored by Git) and run `terraform init -backend-config=backend.hcl`.

Then commit `backend.tf` and `.terraform.lock.hcl`.

## Configure GitHub

1. **Variables** (Settings > Secrets and variables > Actions > Variables): create the four values printed by `terraform output github_actions_variables`. Role ARNs are not secrets, so variables are enough.
2. **Environment** (Settings > Environments): create `production`, add yourself as required reviewer and allow deployments from `main` only.
3. **Ruleset** (Settings > Rules > Rulesets): on `main`, require a pull request and the `terraform-ci` checks before merging.
4. **End-to-end check** (Actions > aws-oidc-check > Run workflow): the job prints the subject claim GitHub sent, which must start with `terraform output github_oidc_subject_prefix`, then the identity of the assumed `lz-github-plan` role. If AWS answers `Not authorized to perform sts:AssumeRoleWithWebIdentity`, those two values differ.

## Design choices

- Why S3 native locking and SSE-S3: [ADR 0002](../docs/adr/0002-terraform-state-in-s3-with-native-locking.md).
- Why two CI roles with different trust conditions: [ADR 0003](../docs/adr/0003-github-actions-oidc-with-split-roles.md).

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
