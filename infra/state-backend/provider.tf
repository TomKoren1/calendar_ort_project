provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "calendar"
      ManagedBy = "terraform"
      Stack     = "state-backend"
    }
  }
}
