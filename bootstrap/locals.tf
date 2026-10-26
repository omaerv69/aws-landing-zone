locals {
  # Every stack reads the same configuration file: adapting the landing zone
  # to a new context starts there, not in the code.
  config = yamldecode(file("${path.module}/../config/landing-zone.yaml"))

  project     = local.config.project
  home_region = local.config.home_region
  github      = local.config.github

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # The account ID and the region make the name globally unique without a
  # random suffix, and tell at a glance where the bucket lives.
  state_bucket_name = "${local.project}-tfstate-${local.account_id}-${local.home_region}"

  default_tags = {
    Project    = local.project
    Owner      = local.config.owner
    ManagedBy  = "terraform"
    Stack      = "bootstrap"
    Repository = "${local.github.owner}/${local.github.repository}"
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
