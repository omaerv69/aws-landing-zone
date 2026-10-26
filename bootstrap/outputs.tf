output "state_bucket" {
  description = "S3 bucket that stores every Terraform state of the landing zone."
  value       = aws_s3_bucket.state.bucket
}

output "github_plan_role_arn" {
  description = "IAM role assumed by GitHub Actions to run terraform plan."
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "IAM role assumed by GitHub Actions to run terraform apply."
  value       = aws_iam_role.github_apply.arn
}

output "github_oidc_subject_prefix" {
  description = "Prefix the trust policies expect in the subject claim sent by GitHub. Compare it with the aws-oidc-check workflow output when debugging."
  value       = local.github_subject_prefix
}

output "github_actions_variables" {
  description = "Repository variables to create in GitHub (Settings > Secrets and variables > Actions > Variables)."
  value = {
    AWS_REGION         = local.home_region
    TF_STATE_BUCKET    = aws_s3_bucket.state.bucket
    AWS_PLAN_ROLE_ARN  = aws_iam_role.github_plan.arn
    AWS_APPLY_ROLE_ARN = aws_iam_role.github_apply.arn
  }
}
