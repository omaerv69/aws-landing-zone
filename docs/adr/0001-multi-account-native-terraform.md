# 0001. Multi-account landing zone in native Terraform, without Control Tower at first

- Status: Accepted
- Date: 2026-10-26

## Context

The landing zone must be reproducible from scratch in a new AWS organization, adaptable to different contexts through configuration, and cheap enough to run as a personal lab. It is also a learning project: understanding what each building block does matters as much as the result.

## Decision

Build the foundation in Terraform directly on top of AWS Organizations, with the account structure of the AWS Security Reference Architecture: Security, Infrastructure, Workloads, Sandbox and Suspended organizational units, under a management account that only governs.

## Consequences

Positive:

- Every component (organization trail, delegated administrators, service control policies) is explicit, reviewed in pull requests and understood.
- The networking, security and workload modules remain reusable in an organization that already runs Control Tower.
- Each layer has its own lifecycle, which makes the deploy and destroy cycle possible.

Negative:

- What Control Tower provides out of the box (a managed library of controls, drift detection, an account factory with a console) has to be built or done without.
- The organization layer is persistent: account closure is rate limited and a closed account stays suspended for 90 days, so accounts are never part of the destroy cycle.

## Alternatives considered

- **AWS Control Tower.** The managed service most organizations use. Since landing zone 4.0 (November 2025), its integrations with AWS Config, CloudTrail, security roles and AWS Backup are optional and it no longer imposes an OU structure, which makes it easier to layer on top of an existing organization. It hides the mechanisms this project wants to learn, so it is kept for later, in Controls-Only mode, for its library of controls.
- **Landing Zone Accelerator on AWS.** A configuration-driven solution deployed with CloudFormation and the AWS CDK. Complete, but its size and its toolchain do not fit a Terraform-first project.
- **A single account.** Simpler and cheaper, but it removes the isolation boundary the whole design relies on.
