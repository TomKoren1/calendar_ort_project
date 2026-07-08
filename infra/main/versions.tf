terraform {
  required_version = ">= 1.5"

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
  # local for bootstrap reasons) - this is the stack meant to be applied and
  # destroyed every working session, so its state must survive that cycle.
  # Bucket/table created once, by hand, in infra/state-backend/ - see that
  # module's README for why it must never be destroyed.
  backend "s3" {
    bucket         = "calendar-terraform-state-672299759593"
    key            = "main/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "calendar-terraform-locks"
    encrypt        = true
  }
}
