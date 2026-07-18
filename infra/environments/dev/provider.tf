provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "calendar"
      ManagedBy   = "terraform"
      Stack       = "main"
      Environment = "dev"
    }
  }
}

# helm/kubectl/kubernetes all authenticate against the cluster module.cluster
# just created, using a short-lived token from the AWS CLI (same underlying
# mechanism as `aws eks update-kubeconfig` - no static credential stored).
# These provider blocks - and this file existing per environment at all - are
# the one piece of duplication plain Terraform can't avoid (provider config
# must live in the root, not a module); this is exactly what Terragrunt's
# `generate` block exists to template away later, if a third environment ever
# justifies adopting it (see infra/environments/README.md).
data "aws_eks_cluster_auth" "this" {
  name = module.cluster.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

provider "kubernetes" {
  host                   = module.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
