terraform {
  required_version = ">= 1.10" # use_lockfile (native S3 locking) needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl" # gavinbunney/kubectl is unmaintained
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }

  # Real remote state, unlike infra/bootstrap/ and infra/state-backend/ (both
  # local for bootstrap reasons) - this environment is applied and destroyed
  # every working session, so its state must survive that cycle. Bucket
  # created once, by hand, in infra/state-backend/ - shared with staging/,
  # distinguished only by `key`, matching the bootcamp's "Golden Rule: each
  # environment gets its own state file" (05-terraform/01-fundamentals/
  # 07-project-structure). Locking is native S3 (use_lockfile, Terraform
  # 1.10+) - an atomic conditional PutObject creates a companion .tflock
  # object, no separate DynamoDB table needed.
  backend "s3" {
    bucket       = "calendar-terraform-state-672299759593"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
