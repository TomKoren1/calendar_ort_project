provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "calendar"
      ManagedBy = "terraform"
      Stack     = "main"
    }
  }
}

# helm/kubectl both authenticate against the cluster this same apply just
# created, using a short-lived token from the AWS CLI (same underlying
# mechanism as `aws eks update-kubeconfig` - no static credential stored).
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
