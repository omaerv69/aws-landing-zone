# 0002. Terraform state in S3 with native locking, one state per stack

- Status: Accepted
- Date: 2026-10-26

## Context

Every stack needs a remote, shared and locked state that works both from a workstation and from GitHub Actions. Since Terraform 1.11, the S3 backend can lock a state with a lock file stored next to it, and DynamoDB-based locking is deprecated.

## Decision

- One versioned S3 bucket in the management account stores all states, with one key per stack (`bootstrap/terraform.tfstate`, `stacks/<name>/terraform.tfstate`).
- Locking uses the native S3 lock file (`use_lockfile = true`). There is no DynamoDB table.
- Objects are encrypted with SSE-S3. The states are designed to hold no secrets, so a customer managed KMS key would add a monthly fee and a key policy to maintain for little benefit.
- The bucket name is passed at init time (partial backend configuration), which keeps account IDs out of the public repository.
- The bucket is protected by `prevent_destroy` and is never part of the destroy cycle.

## Consequences

Positive:

- One service to manage, and nothing billed while idle beyond a few kilobytes of storage.
- A failed or interrupted apply never loses history, thanks to versioning.
- One state per stack limits the blast radius of a mistake and lets each layer be destroyed on its own.

Negative:

- The bootstrap stack starts with a local state and has to be migrated once into the bucket it creates.
- Keeping states in the management account is a compromise. They may move to a dedicated account once the organization exists.

## Alternatives considered

- **DynamoDB locking.** Deprecated by Terraform and one more resource to manage.
- **HCP Terraform.** Convenient, but it moves states and runs outside AWS and does not teach the backend mechanics.
- **SSE-KMS with a customer managed key.** To reconsider if a state ever has to hold a secret.
