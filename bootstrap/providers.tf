# Credentials come from the environment: an IAM Identity Center profile on a
# workstation (AWS_PROFILE), never an access key.
provider "aws" {
  region = local.home_region

  default_tags {
    tags = local.default_tags
  }
}
