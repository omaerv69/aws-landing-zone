# Stacks

Root modules, each with its own state key in the state bucket. CI applies them in a fixed order, and they are grouped by lifecycle so that billed layers can be destroyed without touching the foundation.

Planned layout:

| Order | Stack | Content | Lifecycle |
|---|---|---|---|
| 10 | `organization` | OUs, accounts, organization policies | Persistent, never destroyed |
| 20 | `identity` | IAM Identity Center groups and permission sets | Persistent |
| 30 | `security` | Organization trail, AWS Config, GuardDuty, Security Hub | Each service toggled by a flag in the configuration file |
| 40 | `network` | IPAM, Transit Gateway, egress, DNS | Ephemeral |
| 50 | `workloads` | Blueprint instances per account | Ephemeral |

Every stack reads `config/landing-zone.yaml`. How stacks share their outputs (remote state or SSM Parameter Store) will be decided in an ADR during phase 1.
