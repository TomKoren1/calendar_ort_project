terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Intentionally local state (terraform.tfstate on disk, gitignored) for this
  # bootstrap stack only: it exists specifically to create the ECR repos +
  # OIDC role that a "real" remote-state backend (S3 + DynamoDB, Step 4) would
  # otherwise need to already exist to authenticate to. Everything after Step
  # 4 uses proper remote state.
}
