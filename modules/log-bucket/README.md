# log-bucket module

A private, encrypted, versioned S3 bucket for security logs (CloudTrail, VPC flow
logs, WAF logs), with a TLS-only policy and a lifecycle that keeps storage costs
down.

## What it creates

| Resource | Purpose |
|---|---|
| S3 bucket | Named `<name_prefix>-logs-<account id>` unless you set `bucket_name` |
| Public access block | All four flags on |
| Ownership controls | `BucketOwnerEnforced`, so ACLs are disabled |
| Versioning | Enabled |
| Default encryption | SSE-S3 (AES256), or SSE-KMS if you pass `kms_key_arn` |
| Bucket policy | Denies non-TLS and TLS < 1.2, plus any statements you pass in |
| Lifecycle | Transition large logs to colder storage, then expire |

## Usage

```hcl
module "log_bucket" {
  source = "../../modules/log-bucket"

  name_prefix = "acme-web-dev"
  tags        = { Environment = "dev", ManagedBy = "terraform" }
}
```

### Letting AWS services write to the bucket

A bucket has exactly one policy, so services that must write here (CloudTrail,
VPC flow logs) do not attach their own policy. They build an allow statement and
pass it in through `source_policy_documents`. The module merges it with the two
deny statements. The logging task shows a full example.

### Using a KMS key

```hcl
kms_key_arn = aws_kms_key.logs.arn   # a key ARN, not an alias
```

The key policy must allow the writing services to use the key. A bucket key is
turned on automatically to cut KMS request costs.

## Encryption: SSE-S3 or KMS?

| | SSE-S3 (default) | SSE-KMS (`kms_key_arn`) |
|---|---|---|
| Cost | Free | KMS key about $1/month plus requests |
| Setup | None | Key policy for each writing service |
| Audit | Bucket-level | Every decrypt is logged in CloudTrail |
| Control | AWS-managed | You can restrict or revoke the key |

SSE-S3 is encrypted at rest and is fine for many small workloads. Choose KMS when
you need key-level access control or a compliance requirement asks for it.

## Lifecycle (defaults)

| Rule | Applies to | Action |
|---|---|---|
| `transition-large-logs` | Objects over 128 KiB | Standard-IA at 30 days, Glacier Instant Retrieval at 90 days |
| `expire-logs` | All objects | Delete at 365 days; delete old versions at 30 days; clean up stale multipart uploads at 7 days |

- Small objects are not transitioned. The per-request charge and minimum billable
  size make it cost more than it saves, and many log files are small.
- Glacier **Instant** Retrieval is used so old logs stay queryable with Athena.
  Glacier Flexible Retrieval would make them unreadable until restored.
- Set `expiration_days` to your required retention period. Validation keeps the
  periods in a valid order.

## Cost

An empty bucket costs nothing. You pay for stored logs (S3 Standard is about
$0.023 per GB-month in us-east-1) and requests. With the lifecycle above, old
logs get cheaper over time and are deleted after the retention period. Prices
vary by region; check the [S3 pricing page](https://aws.amazon.com/s3/pricing/).

## Destroying it

`force_destroy` is `false` by default, so `terraform destroy` fails while the
bucket still holds logs. That protects real log data. For a short-lived demo,
set `force_destroy = true`.

## Not included yet

Listed on purpose so nobody assumes they are covered:

- Server access logging for this bucket (a log bucket logging to itself adds
  noise, not security)
- S3 Object Lock or MFA delete (immutable logs)
- Cross-region replication
- Event notifications

## Tests

```bash
terraform -chdir=modules/log-bucket init -backend=false
terraform -chdir=modules/log-bucket test
```

The tests use a mock AWS provider (no credentials, nothing created). They check
that every public-access flag is on, that ACLs are disabled, that versioning and
encryption are set (SSE-S3 and KMS), that both TLS deny statements exist and
cover the bucket and its objects, the lifecycle rules, and input validation.
