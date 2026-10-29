variable "name_prefix" {
  description = "Short name for the workload, used as the start of every resource name (for example \"acme-web\"). Lowercase letters, digits and hyphens, 3 to 22 characters. It also ends up in globally unique S3 bucket names, so keep it distinctive."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-22 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "environment" {
  description = "Deployment environment. Added to resource names and to the Environment tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Extra tags added to every resource. The standard tags (ManagedBy, Module, Environment) always win, so they cannot be overridden here."
  type        = map(string)
  default     = {}
}
