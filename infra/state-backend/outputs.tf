output "state_bucket_name" {
  description = "Set as the S3 bucket in each infra/environments/*/'s backend \"s3\" block"
  value       = aws_s3_bucket.state.id
}

output "aws_region" {
  value = var.aws_region
}
