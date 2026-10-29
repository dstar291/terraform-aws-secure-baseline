output "name_prefix" {
  description = "Prefix applied to every resource name, in the form <name_prefix>-<environment>."
  value       = local.name_prefix
}

output "tags" {
  description = "Final tag map applied to every resource: caller tags plus the standard tags."
  value       = local.tags
}
