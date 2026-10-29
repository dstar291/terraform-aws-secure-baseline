# vpc module

A VPC across 2 (or 3) Availability Zones with one public and one private subnet
per AZ, internet routing, optional NAT, and a locked-down default security group.

## What it creates

| Resource | Count | Notes |
|---|---|---|
| VPC | 1 | DNS support and hostnames on |
| Internet gateway | 1 | |
| Public subnets | 1 per AZ | Route to the internet gateway. No auto-assigned public IPs. |
| Private subnets | 1 per AZ | No internet route unless NAT is enabled |
| Route tables | 1 public, 1 private per AZ | Per-AZ private tables allow one NAT per AZ |
| NAT gateway + Elastic IP | 0 (default), 1, or 1 per AZ | Opt-in, see cost below |
| Default security group | 1 | Adopted by Terraform with **all rules removed** |

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name_prefix = "acme-web-dev"
  tags        = { Environment = "dev", ManagedBy = "terraform" }
}
```

Inputs and outputs are documented in `variables.tf` and `outputs.tf`.

## Address plan

With the defaults (`10.0.0.0/16`, `subnet_newbits = 4`) every subnet is a /20
(4,091 usable addresses):

| Tier | AZ 1 | AZ 2 | AZ 3 (optional) |
|---|---|---|---|
| Public | 10.0.0.0/20 | 10.0.16.0/20 | 10.0.32.0/20 |
| Private | 10.0.128.0/20 | 10.0.144.0/20 | 10.0.160.0/20 |

Private subnets start at slot 8, which leaves slots 3 to 7 and 11 to 15 free
for new tiers (for example a database tier) without renumbering.

## Cost

The VPC, subnets, route tables and internet gateway are free. **NAT gateways are
the only meaningful cost**, so they are off by default:

- About $36 per month per NAT gateway in us-east-1 (hourly charge plus the
  public IPv4 address charge), plus about $0.045 per GB of data processed.
- `enable_nat_gateway = true` creates one shared gateway (cheapest).
- `single_nat_gateway = false` creates one per AZ (survives an AZ outage, costs
  about twice as much with 2 AZs).
- Prices vary by region and change over time. Check the
  [AWS pricing page](https://aws.amazon.com/vpc/pricing/) before you apply.

With NAT off, private subnets cannot reach the internet. Use VPC endpoints
(planned) for AWS services, or turn NAT on if your workload needs outbound access.

## Security decisions

- **Default security group has no rules.** AWS's default allows all traffic
  between its members. Terraform adopts it and removes every rule. Create
  dedicated security groups for workloads.
- **No auto-assigned public IPs**, even in public subnets. Put internet-facing
  things (load balancer, NAT) there on purpose.
- **At least 2 AZs.** A single AZ is not highly available, so `az_count = 1`
  is rejected.
- **Not included yet:** VPC flow logs (added by the logging task), network ACL
  customization and IPv6.

## Tests

```bash
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc test
```

The tests use a mock AWS provider, so they need no credentials and create
nothing. They check subnet counts, the CIDR math, that NAT is opt-in, that the
default security group has no rules, and that bad inputs are rejected.
