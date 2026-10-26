terraform {
  # Pinned to a minor release. The exact version lives in /.terraform-version
  # and is used by CI and by version managers such as tenv or tfenv.
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
