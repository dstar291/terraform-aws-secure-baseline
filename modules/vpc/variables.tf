variable "name_prefix" {
  description = "Prefix for the Name tag of every resource, for example \"acme-web-dev\". Lowercase letters, digits and hyphens, 3 to 30 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-30 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC. Must be between /16 and /24. Use a private range (RFC 1918) that does not overlap networks you will peer or connect to."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, for example 10.0.0.0/16."
  }

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) ? (tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24) : false
    error_message = "vpc_cidr prefix length must be between /16 and /24."
  }
}

variable "subnet_newbits" {
  description = "Number of extra prefix bits for each subnet. 4 splits a /16 VPC into /20 subnets (4,096 addresses). Public subnets use slots 0..az_count-1 and private subnets use slots 8..8+az_count-1."
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 8
    error_message = "subnet_newbits must be between 4 and 8."
  }

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) ? tonumber(split("/", var.vpc_cidr)[1]) + var.subnet_newbits <= 28 : false
    error_message = "vpc_cidr prefix plus subnet_newbits must not exceed 28, the smallest subnet AWS allows."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across. Each AZ gets one public and one private subnet."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3, because a single AZ is not highly available."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets can reach the internet. Off by default because each NAT gateway costs roughly $35 per month. With it off, private subnets have no internet route."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When enable_nat_gateway is true: use one shared NAT gateway (cheaper, but an AZ outage removes internet access for all private subnets) instead of one per AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags added to every resource. A Name tag is set per resource."
  type        = map(string)
  default     = {}
}
