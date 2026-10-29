variables {
  name_prefix = "acme-web"
}

run "defaults_build_name_and_standard_tags" {
  command = plan

  assert {
    condition     = output.name_prefix == "acme-web-dev"
    error_message = "name_prefix should be <name_prefix>-<environment>."
  }

  assert {
    condition = output.tags == {
      ManagedBy   = "terraform"
      Module      = "terraform-aws-secure-baseline"
      Environment = "dev"
    }
    error_message = "Default tags should be exactly the three standard tags."
  }
}

run "caller_tags_merge_but_cannot_override_standard_tags" {
  command = plan

  variables {
    environment = "prod"
    tags = {
      Owner     = "platform"
      ManagedBy = "manual"
    }
  }

  assert {
    condition     = output.tags["Owner"] == "platform"
    error_message = "Caller tags should be kept."
  }

  assert {
    condition     = output.tags["ManagedBy"] == "terraform"
    error_message = "Standard tags must win over caller tags."
  }

  assert {
    condition     = output.tags["Environment"] == "prod" && output.name_prefix == "acme-web-prod"
    error_message = "Environment should drive both the tag and the name."
  }
}

run "rejects_uppercase_name_prefix" {
  command = plan

  variables {
    name_prefix = "Acme"
  }

  expect_failures = [var.name_prefix]
}

run "rejects_trailing_hyphen_in_name_prefix" {
  command = plan

  variables {
    name_prefix = "acme-"
  }

  expect_failures = [var.name_prefix]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
