terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state, deliberately: this module CREATES the S3 bucket + DynamoDB
  # table that infra/main/'s remote backend depends on, so it can't itself
  # depend on that backend existing yet - same bootstrap reasoning as
  # infra/bootstrap/. Unlike infra/main/, this stack is applied ONCE and
  # never destroyed - see this module's own README.
}
