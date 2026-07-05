variable "aws_region" {
  description = "AWS region to create the ECR repositories and IAM resources in"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization/user that owns the repo (used to scope the OIDC trust condition)"
  type        = string
  default     = "TomKoren1"
}

variable "github_repo" {
  description = "GitHub repository name (used to scope the OIDC trust condition)"
  type        = string
  default     = "calendar_ort_project"
}

variable "github_branch" {
  description = "Branch allowed to assume the CI role via OIDC (build-and-push only runs on push to this branch)"
  type        = string
  default     = "main"
}
