provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "calendar"
      ManagedBy   = "terraform"
      Stack       = "main"
      Environment = "staging"
    }
  }
}

# See infra/environments/dev/provider.tf's comment - identical mechanism,
# duplicated per environment because Terraform provider blocks can't live in
# a shared module.
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
