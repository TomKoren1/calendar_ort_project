output "state_bucket_name" {
  description = "Set as the S3 bucket in infra/main/'s backend \"s3\" block"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Set as the DynamoDB table in infra/main/'s backend \"s3\" block"
  value       = aws_dynamodb_table.locks.name
}

output "aws_region" {
  value = var.aws_region
}
