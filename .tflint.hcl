# Shared by pre-commit and CI. The AWS ruleset will be enabled with the first
# stacks that create infrastructure (phase 1).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
