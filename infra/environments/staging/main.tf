module "cluster" {
  source = "../../modules/eks-cluster"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
}

module "addons" {
  source = "../../modules/platform-addons"

  aws_region             = var.aws_region
  cluster_name           = module.cluster.cluster_name
  cluster_arn            = module.cluster.cluster_arn
  cluster_endpoint       = module.cluster.cluster_endpoint
  vpc_id                 = module.cluster.vpc_id
  private_subnet_ids     = module.cluster.private_subnet_ids
  node_security_group_id = module.cluster.node_security_group_id
  oidc_provider          = module.cluster.oidc_provider
  oidc_provider_arn      = module.cluster.oidc_provider_arn

  karpenter_capacity_types = var.karpenter_capacity_types
  addon_replica_count      = var.addon_replica_count
  rds_multi_az             = var.rds_multi_az
}
