# terraform-aws-secure-baseline

An opinionated, tested Terraform baseline for a **secure AWS web workload**, sized
for small teams that do not have a dedicated cloud security engineer.

> **Status: pre-release (v0.x), under active development.** Nothing here is
> deployable yet. The README only describes what exists, and it will grow
> with the code.

## Goal

Give a small team a safe starting point on AWS that they can deploy in about
15 minutes and understand end to end:

- Network: VPC across 2 AZs with public and private subnets
- Logging: encrypted central log bucket, VPC flow logs, CloudTrail
- Edge protection: WAFv2 web ACL (AWS managed rules plus rate limiting) with logging
- Visibility: Athena database and saved queries for WAF logs
- Delivery: GitHub OIDC role for CI, with no static AWS keys

Each item is added as a small, reviewed change.

## Modules

| Module | Status | What it does |
|---|---|---|
| [`modules/vpc`](modules/vpc/README.md) | Available | VPC, public and private subnets across 2 AZs, optional NAT, locked-down default security group |

## Design principles

1. **Secure defaults.** Encryption on, public access blocked, least privilege.
2. **Small blast radius.** Independent modules with feature toggles, so you adopt
   only what you need.
3. **Cost-aware.** Every module documents its approximate monthly cost.
4. **Tested.** `terraform fmt`, `validate`, `tflint`, `checkov` and
   `terraform test` run on every pull request.
5. **No surprise applies.** CI never runs `terraform apply`. You review the plan.

## Cost and safety

Applying this code creates billable AWS resources (NAT gateways, WAF, CloudTrail
and log storage). Use a **dedicated, non-production AWS account**, set an AWS
Budget alert first, and run `terraform destroy` when you are finished.

This project reduces risk but does not guarantee compliance or security. Review
the plan before you apply it, and review the code before you trust it.

## Development

Requirements: Terraform 1.9+, [tflint](https://github.com/terraform-linters/tflint),
Python (for pre-commit).

```bash
pip install pre-commit
pre-commit install
tflint --init          # one-time: downloads the tflint rulesets
pre-commit run --all-files

terraform init -backend=false
terraform validate
terraform test

# each module is tested on its own
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc test
```

Hooks: whitespace and YAML checks, `terraform fmt`, `tflint` and `gitleaks`
(secret scanning). Never commit credentials, state files or `*.tfvars`.

Conventions for names and tags are in [docs/tagging.md](docs/tagging.md).

## How this repository is built

Built with AI assistance, human-reviewed. An AI assistant helps draft changes,
and every change is read, understood and approved by the maintainer before it
is merged. All work is done in small commits that follow
[Conventional Commits](https://www.conventionalcommits.org/). Commit dates are
real and history is never rewritten.

## License

[MIT](LICENSE)
