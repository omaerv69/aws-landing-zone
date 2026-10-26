# Architecture Decision Records

Each significant decision gets a short record: its context, the decision itself and its consequences. An accepted record is never rewritten. When a decision changes, a new record supersedes the old one.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-multi-account-native-terraform.md) | Multi-account landing zone in native Terraform, without Control Tower at first | Accepted |
| [0002](0002-terraform-state-in-s3-with-native-locking.md) | Terraform state in S3 with native locking, one state per stack | Accepted |
| [0003](0003-github-actions-oidc-with-split-roles.md) | GitHub Actions through OIDC, with separate plan and apply roles | Accepted |

To add one, copy [template.md](template.md) to the next number and open a pull request.
