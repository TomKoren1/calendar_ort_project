# Cluster identity/network values - passed in directly from the eks-cluster
# module's outputs by the environment root (not looked up via
# terraform_remote_state, since both modules are called from the same root in
# the same apply - see infra/environments/*/main.tf).

variable "aws_region" {
  description = "AWS region for all resources in this stack"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_security_group_id" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

# ===== Environment-tier configuration =====
# These are the actual knobs that differ between dev and staging - see
# infra/environments/{dev,staging}/terraform.tfvars.

variable "karpenter_capacity_types" {
  description = "Karpenter NodePool capacity types. dev includes spot for cost; staging is on-demand only to avoid spot-interruption risk."
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_instance_sizes" {
  description = "Karpenter NodePool allowed instance sizes (t-family only, cost-optimized)"
  type        = list(string)
  default     = ["small", "medium"]
}

variable "addon_replica_count" {
  description = "Replica count for the ALB controller, ingress-nginx controller, and Karpenter controller. 1 for dev, 2 for staging to demonstrate basic HA."
  type        = number
  default     = 1
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_multi_az" {
  description = "Whether RDS runs Multi-AZ (real failover). false for dev (cost), true for staging (HA demonstration)."
  type        = bool
  default     = false
}
