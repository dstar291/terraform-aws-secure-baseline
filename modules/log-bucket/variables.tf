variable "name_prefix" {
  description = "Prefix for resource names, for example \"acme-web-dev\". Lowercase letters, digits and hyphens, 3 to 30 characters. Used to build the bucket name unless bucket_name is set."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-30 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "bucket_name" {
  description = "Exact bucket name. Leave null to use \"<name_prefix>-logs-<account id>\", which is globally unique. Set it when a service needs a specific name, for example WAF logging requires the prefix \"aws-waf-logs-\"."
  type        = string
  default     = null

  validation {
    condition     = var.bucket_name == null ? true : can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters: lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "kms_key_arn" {
  description = "ARN of a customer-managed KMS key for default encryption. Leave null to use S3-managed keys (SSE-S3, free). If you set a key, its key policy must allow the AWS services that write logs to use it."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias."
  }
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the bucket even when it still holds logs. Keep false for real environments. Set true only for short-lived demos."
  type        = bool
  default     = false
}

variable "source_policy_documents" {
  description = "Extra bucket policy documents (JSON) merged into the bucket policy. A bucket has only one policy, so services that must write here (CloudTrail, VPC flow logs) pass their allow statements through this input."
  type        = list(string)
  default     = []
}

variable "transition_to_ia_days" {
  description = "Days after creation before large objects move to Standard-IA. S3 requires at least 30."
  type        = number
  default     = 30

  validation {
    condition     = var.transition_to_ia_days >= 30
    error_message = "transition_to_ia_days must be at least 30, the S3 minimum for Standard-IA."
  }
}

variable "transition_to_glacier_ir_days" {
  description = "Days after creation before large objects move to Glacier Instant Retrieval. Must be at least 30 days after the Standard-IA transition. Glacier Instant Retrieval keeps objects queryable (for example with Athena), unlike Glacier Flexible Retrieval."
  type        = number
  default     = 90

  validation {
    condition     = var.transition_to_glacier_ir_days >= var.transition_to_ia_days + 30
    error_message = "transition_to_glacier_ir_days must be at least transition_to_ia_days + 30."
  }
}

variable "expiration_days" {
  description = "Days after creation before logs are deleted. Pick the period your compliance requirements need, for example 365 for one year."
  type        = number
  default     = 365

  validation {
    condition     = var.expiration_days > var.transition_to_glacier_ir_days
    error_message = "expiration_days must be greater than transition_to_glacier_ir_days."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days before overwritten or deleted object versions are permanently removed."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
