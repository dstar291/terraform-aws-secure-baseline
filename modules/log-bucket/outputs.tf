output "bucket_id" {
  description = "Name (ID) of the log bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the log bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_policy_json" {
  description = "The final bucket policy document, useful for review."
  value       = data.aws_iam_policy_document.this.json
}
