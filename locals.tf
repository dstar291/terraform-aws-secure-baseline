locals {
  # "<name_prefix>-<environment>", e.g. "acme-web-dev". Every resource name starts with this.
  name_prefix = "${var.name_prefix}-${var.environment}"

  # Caller tags first, standard tags last, so the standard tags always win.
  tags = merge(
    var.tags,
    {
      ManagedBy   = "terraform"
      Module      = "terraform-aws-secure-baseline"
      Environment = var.environment
    },
  )
}
