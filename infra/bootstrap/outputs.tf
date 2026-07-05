output "ecr_backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "github_actions_role_arn" {
  description = "Set as the role-to-assume input for aws-actions/configure-aws-credentials in CI (Step 1d)"
  value       = aws_iam_role.github_actions_ecr_push.arn
}
