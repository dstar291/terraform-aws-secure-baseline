# Tagging convention

Every resource this module creates carries the same tag map. Consistent tags make
cost reports, ownership and security policies reliable.

## Standard tags (always applied)

| Tag           | Value                            | Why                                          |
|---------------|----------------------------------|----------------------------------------------|
| `ManagedBy`   | `terraform`                      | Tells people not to edit it by hand.         |
| `Module`      | `terraform-aws-secure-baseline`  | Traces a resource back to this code.         |
| `Environment` | `dev`, `staging` or `prod`       | Filters cost and access by environment.      |

## Your own tags

Pass extra tags with the `tags` variable. They are added to every resource:

```hcl
tags = {
  Owner      = "platform-team"
  CostCenter = "1234"
}
```

The standard tags are applied last, so they cannot be overridden. This keeps
tag-based cost reports and policies trustworthy.

## Naming

Resource names start with `<name_prefix>-<environment>`, for example
`acme-web-prod`. `name_prefix` is 3 to 22 lowercase letters, digits and hyphens.
It is short on purpose: it is reused in globally unique S3 bucket names, which
are limited to 63 characters.

## Region

Modules do not take a `region` variable. They use whichever region the caller's
AWS provider is configured for, which avoids two sources of truth. The region
is set once, in the example or in your own root configuration.
