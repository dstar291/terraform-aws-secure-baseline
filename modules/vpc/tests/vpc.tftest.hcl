mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

variables {
  name_prefix = "acme-web-dev"
}

run "defaults_two_azs_with_expected_cidrs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Default is 2 AZs: expect 2 public and 2 private subnets."
  }

  assert {
    condition     = join(",", output.availability_zones) == "us-east-1a,us-east-1b"
    error_message = "Should use the first two available AZs."
  }

  # 10.0.0.0/16 with 4 extra bits = /20 subnets. Public = slots 0,1. Private = slots 8,9.
  assert {
    condition     = output.public_subnet_cidrs == ["10.0.0.0/20", "10.0.16.0/20"]
    error_message = "Public subnet CIDRs are wrong."
  }

  assert {
    condition     = output.private_subnet_cidrs == ["10.0.128.0/20", "10.0.144.0/20"]
    error_message = "Private subnet CIDRs are wrong."
  }

  assert {
    condition     = length(distinct(concat(output.public_subnet_cidrs, output.private_subnet_cidrs))) == 4
    error_message = "Subnet CIDRs must not overlap."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "DNS support and hostnames should be enabled."
  }
}

run "subnets_do_not_auto_assign_public_ips" {
  command = plan

  assert {
    condition     = alltrue([for s in concat(aws_subnet.public, aws_subnet.private) : s.map_public_ip_on_launch == false])
    error_message = "No subnet may auto-assign public IPs."
  }
}

run "subnets_are_in_distinct_azs" {
  command = plan

  assert {
    condition     = length(distinct(aws_subnet.public[*].availability_zone)) == 2 && length(distinct(aws_subnet.private[*].availability_zone)) == 2
    error_message = "Each tier should span two different AZs."
  }
}

run "no_nat_gateway_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0 && length(aws_route.private_nat) == 0
    error_message = "NAT must be opt-in: no NAT gateway, EIP or private NAT route by default."
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "There should still be one private route table per AZ."
  }
}

run "public_route_goes_to_internet_gateway" {
  command = plan

  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public default route should be 0.0.0.0/0."
  }

  assert {
    condition     = length(aws_route_table_association.public) == 2 && length(aws_route_table_association.private) == 2
    error_message = "Every subnet should be associated with a route table."
  }
}

run "single_nat_gateway_when_enabled" {
  command = plan

  variables {
    enable_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_eip.nat) == 1
    error_message = "Default NAT mode is a single shared gateway."
  }

  assert {
    condition     = length(aws_route.private_nat) == 2
    error_message = "Every private route table should route to the NAT gateway."
  }
}

run "nat_gateway_per_az_when_requested" {
  command = plan

  variables {
    enable_nat_gateway = true
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2 && length(aws_eip.nat) == 2
    error_message = "single_nat_gateway = false should create one NAT gateway per AZ."
  }
}

run "three_azs" {
  command = plan

  variables {
    az_count = 3
  }

  assert {
    condition     = output.public_subnet_cidrs == ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
    error_message = "Three AZs should give three public subnets."
  }

  assert {
    condition     = output.private_subnet_cidrs == ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
    error_message = "Three AZs should give three private subnets."
  }
}

run "custom_cidr_and_newbits" {
  command = plan

  variables {
    vpc_cidr       = "172.16.0.0/20"
    subnet_newbits = 4
  }

  # /20 + 4 bits = /24 subnets.
  assert {
    condition     = output.public_subnet_cidrs == ["172.16.0.0/24", "172.16.1.0/24"]
    error_message = "CIDR math should follow vpc_cidr and subnet_newbits."
  }

  assert {
    condition     = output.private_subnet_cidrs == ["172.16.8.0/24", "172.16.9.0/24"]
    error_message = "Private subnets should start at slot 8."
  }
}

run "default_security_group_has_no_rules" {
  command = apply

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0
    error_message = "The default security group must have no ingress rules."
  }

  assert {
    condition     = length(aws_default_security_group.this.egress) == 0
    error_message = "The default security group must have no egress rules."
  }
}

run "tags_are_applied_with_name" {
  command = plan

  variables {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "acme-web-dev-vpc" && aws_vpc.this.tags["ManagedBy"] == "terraform"
    error_message = "VPC should carry the Name tag and caller tags."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["Tier"] == "public"]) && alltrue([for s in aws_subnet.private : s.tags["Tier"] == "private"])
    error_message = "Subnets should carry a Tier tag."
  }
}

run "rejects_bad_name_prefix" {
  command = plan

  variables {
    name_prefix = "Bad_Name"
  }

  expect_failures = [var.name_prefix]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_vpc_smaller_than_slash_24" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/25"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_subnets_smaller_than_slash_28" {
  command = plan

  variables {
    vpc_cidr       = "10.0.0.0/24"
    subnet_newbits = 5
  }

  expect_failures = [var.subnet_newbits]
}

run "rejects_single_az" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "fails_when_region_has_too_few_azs" {
  command = plan

  variables {
    az_count = 3
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  expect_failures = [aws_vpc.this]
}
