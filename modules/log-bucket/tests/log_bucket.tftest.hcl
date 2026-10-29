mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012" # the AWS documentation example account, not a real one
    }
  }

  # The real policy JSON is built by the provider; the mock needs any valid JSON.
  # The statements themselves are checked from the data source's configuration.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix = "acme-web-dev"
}

run "default_bucket_name_uses_prefix_and_account" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "acme-web-dev-logs-123456789012"
    error_message = "Default bucket name should be <name_prefix>-logs-<account id>."
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Name"] == "acme-web-dev-logs-123456789012"
    error_message = "Bucket should carry a Name tag."
  }
}

run "bucket_name_can_be_overridden" {
  command = plan

  variables {
    bucket_name = "aws-waf-logs-acme-web-dev"
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "aws-waf-logs-acme-web-dev"
    error_message = "bucket_name should override the generated name."
  }
}

run "every_public_access_flag_is_true" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true."
  }
}

run "acls_are_disabled" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled with BucketOwnerEnforced."
  }
}

run "versioning_is_enabled" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "Versioning must be enabled."
  }
}

run "default_encryption_is_sse_s3" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Without a KMS key the bucket should use SSE-S3 (AES256)."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == false
    error_message = "Bucket key is only useful with KMS."
  }
}

run "kms_key_switches_encryption_to_kms" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "With a key ARN the bucket should use aws:kms."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "The given KMS key should be used."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true
    error_message = "Bucket key should be on with KMS to reduce request costs."
  }
}

run "tls_only_deny_statement_exists" {
  # apply (against the mock provider, nothing real is created) so bucket ARNs are known
  command = apply

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.sid == "DenyInsecureTransport" && s.effect == "Deny"
      && anytrue([for c in s.condition : c.test == "Bool" && c.variable == "aws:SecureTransport" && contains(c.values, "false")])
    ])
    error_message = "A Deny statement for aws:SecureTransport = false must exist."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.sid == "DenyOutdatedTls" && s.effect == "Deny"
      && anytrue([for c in s.condition : c.test == "NumericLessThan" && c.variable == "s3:TlsVersion" && contains(c.values, "1.2")])
    ])
    error_message = "A Deny statement for TLS versions below 1.2 must exist."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.this.statement :
      length(s.resources) == 2 && anytrue([for r in s.resources : endswith(r, "/*")])
    ])
    error_message = "Deny statements must cover both the bucket and its objects."
  }
}

run "extra_policy_documents_are_merged_in" {
  command = plan

  variables {
    source_policy_documents = ["{\"Version\":\"2012-10-17\",\"Statement\":[]}"]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.source_policy_documents) == 1
    error_message = "Caller policy documents should be passed to the policy."
  }
}

run "lifecycle_transitions_large_logs_then_expires" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this.rule) == 2
    error_message = "Expect one transition rule and one expiry rule."
  }

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.this.rule :
      r.id == "transition-large-logs"
      && length(r.transition) == 2
      && anytrue([for t in r.transition : t.days == 30 && t.storage_class == "STANDARD_IA"])
      && anytrue([for t in r.transition : t.days == 90 && t.storage_class == "GLACIER_IR"])
    ])
    error_message = "Large logs should move to Standard-IA at 30 days and Glacier Instant Retrieval at 90."
  }

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.this.rule :
      r.id == "transition-large-logs" && one(r.filter).object_size_greater_than == 131072
    ])
    error_message = "Only objects larger than 128 KiB should transition."
  }

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.this.rule :
      r.id == "expire-logs"
      && one(r.expiration).days == 365
      && one(r.noncurrent_version_expiration).noncurrent_days == 30
      && one(r.abort_incomplete_multipart_upload).days_after_initiation == 7
    ])
    error_message = "Logs should expire at 365 days, old versions at 30 and stale uploads at 7."
  }

  assert {
    condition     = alltrue([for r in aws_s3_bucket_lifecycle_configuration.this.rule : r.status == "Enabled"])
    error_message = "All lifecycle rules must be enabled."
  }
}

run "lifecycle_periods_are_configurable" {
  command = plan

  variables {
    transition_to_ia_days              = 60
    transition_to_glacier_ir_days      = 120
    expiration_days                    = 730
    noncurrent_version_expiration_days = 7
  }

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_lifecycle_configuration.this.rule :
      r.id == "expire-logs" && one(r.expiration).days == 730 && one(r.noncurrent_version_expiration).noncurrent_days == 7
    ])
    error_message = "Expiry periods should follow the variables."
  }
}

run "force_destroy_is_off_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false."
  }
}

run "force_destroy_can_be_enabled_for_demos" {
  command = plan

  variables {
    force_destroy = true
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == true
    error_message = "force_destroy should follow the variable."
  }
}

run "tags_are_applied" {
  command = plan

  variables {
    tags = { ManagedBy = "terraform" }
  }

  assert {
    condition     = aws_s3_bucket.this.tags["ManagedBy"] == "terraform"
    error_message = "Caller tags should be applied to the bucket."
  }
}

run "rejects_bad_name_prefix" {
  command = plan

  variables {
    name_prefix = "Bad_Name"
  }

  expect_failures = [var.name_prefix]
}

run "rejects_bad_bucket_name" {
  command = plan

  variables {
    bucket_name = "Has_Uppercase"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_kms_alias_instead_of_key_arn" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/my-key"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_ia_transition_before_30_days" {
  command = plan

  variables {
    transition_to_ia_days = 7
  }

  expect_failures = [var.transition_to_ia_days]
}

run "rejects_glacier_less_than_30_days_after_ia" {
  command = plan

  variables {
    transition_to_ia_days         = 30
    transition_to_glacier_ir_days = 45
  }

  expect_failures = [var.transition_to_glacier_ir_days]
}

run "rejects_expiry_before_glacier_transition" {
  command = plan

  variables {
    expiration_days = 60
  }

  expect_failures = [var.expiration_days]
}
