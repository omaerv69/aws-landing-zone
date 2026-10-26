locals {
  github_oidc_host         = "token.actions.githubusercontent.com"
  github_immutable_subject = try(local.github.immutable_subject, true)
  github_owner_id          = try(local.github.owner_id, 0)
  github_repository_id     = try(local.github.repository_id, 0)

  # GitHub repositories created after 2026-07-15 send immutable subject
  # claims that embed the owner and repository IDs next to their names. A
  # deleted or renamed repository whose name gets reused by someone else can
  # then never match these trust policies.
  github_subject_prefix = (
    local.github_immutable_subject
    ? "repo:${local.github.owner}@${local.github_owner_id}/${local.github.repository}@${local.github_repository_id}"
    : "repo:${local.github.owner}/${local.github.repository}"
  )
}

# Lets IAM trust the short-lived tokens that GitHub issues to each workflow
# job. No access key is ever stored in GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  # IAM validates GitHub's endpoint against its own trusted root certificate
  # authorities and no longer relies on these thumbprints. They are kept for
  # readability and compatibility.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  lifecycle {
    precondition {
      condition     = local.github.owner != "CHANGE_ME"
      error_message = "Set github.owner in config/landing-zone.yaml before running Terraform."
    }

    precondition {
      condition     = !local.github_immutable_subject || (local.github_owner_id > 0 && local.github_repository_id > 0)
      error_message = "Set github.owner_id and github.repository_id in config/landing-zone.yaml (see bootstrap/README.md)."
    }
  }
}

# ---------------------------------------------------------------------------
# Plan role: read-only, assumable from pull requests and from the main branch.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    sid     = "GitHubActionsPlan"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The subject claim pins the exact repository and the event type.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values = [
        "${local.github_subject_prefix}:pull_request",
        "${local.github_subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${local.project}-github-plan"
  description          = "GitHub Actions: terraform plan (read-only)"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_read_only" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

# Terraform takes a lock even during a plan. With S3 native locking, that
# means creating, reading and deleting a .tflock object next to the state.
data "aws_iam_policy_document" "state_lock" {
  statement {
    sid       = "ManageStateLockFiles"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "github_plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.state_lock.json
}

# ---------------------------------------------------------------------------
# Apply role: full access, assumable only by jobs that run in the protected
# GitHub environment, which requires a manual approval.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_apply_trust" {
  statement {
    sid     = "GitHubActionsApply"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # When a job declares an environment, GitHub puts it in the subject claim
    # instead of the branch: only that environment can assume this role.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = ["${local.github_subject_prefix}:environment:${local.github.apply_environment}"]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name                 = "${local.project}-github-apply"
  description          = "GitHub Actions: terraform apply from the protected environment"
  assume_role_policy   = data.aws_iam_policy_document.github_apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_apply_admin" {
  #checkov:skip=CKV_AWS_274:The landing zone deployer manages Organizations, IAM and every service it builds. A permissions boundary will narrow it in a later phase (ADR 0003).
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}
