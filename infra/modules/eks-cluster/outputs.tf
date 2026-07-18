output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Used by the EKS module (worker nodes) and RDS (DB subnet group), both private-only"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Used by the ALB controller for internet-facing load balancers"
  value       = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider" {
  description = "Used to build the aws_iam_policy_document condition keys for IRSA roles (Karpenter, ALB controller)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "Needed by Karpenter/ALB-controller IRSA roles - the cluster's own OIDC provider, same IRSA mechanism as Step 1c's GitHub OIDC role, different issuer"
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}
