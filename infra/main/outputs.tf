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
