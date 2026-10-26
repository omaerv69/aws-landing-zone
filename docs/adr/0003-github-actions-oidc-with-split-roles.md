# 0003. GitHub Actions through OIDC, with separate plan and apply roles

- Status: Accepted
- Date: 2026-10-26

## Context

CI must run `terraform plan` on pull requests and `terraform apply` after review, from a public repository, without any long-lived AWS credential stored in GitHub.

## Decision

- GitHub Actions authenticates to AWS through an IAM OIDC identity provider. No access key exists anywhere.
- Two roles with different trust conditions:
  - `lz-github-plan`: `ReadOnlyAccess`, plus the right to manage state lock files. Assumable from pull requests and from the `main` branch.
  - `lz-github-apply`: `AdministratorAccess`. Assumable only by jobs running in the GitHub environment `production`, which requires a manual approval and only accepts deployments from `main`.
- Both trust policies pin the audience (`sts.amazonaws.com`) and the exact repository in the subject claim. Repositories created on GitHub after 2026-07-15 send immutable subject claims (`repo:OWNER@OWNER_ID/REPO@REPO_ID:...`), so the policies match the numeric IDs as well as the names. The legacy name-only format remains available through a flag in the configuration file, for older repositories.

## Consequences

Positive:

- A pull request can read the infrastructure but never change it.
- Workflows triggered by pull requests from forks get no OIDC token at all: GitHub does not issue one in that case.
- A deleted or renamed repository whose name is taken over by someone else cannot assume the roles, since its IDs differ.
- Every apply leaves an approval trace in GitHub.

Negative:

- `AdministratorAccess` on the apply role is broader than needed. A permissions boundary will narrow it once the set of managed services is known.
- `ReadOnlyAccess` can read some sensitive metadata. Acceptable for a lab, to review before any use with real data.

## Alternatives considered

- **Access keys stored as GitHub secrets.** Long-lived, hard to rotate, and a single leak exposes the account.
- **One role for both plan and apply.** Simpler, but any workflow on any branch would get write access.
