variable "aws_region" {
  description = "AWS region for all resources in this stack"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  # Kept short deliberately: the EKS module's node-group IAM role name_prefix
  # has a 38-char AWS limit, and "-system-eks-node-group-" alone eats 23 of
  # them - see infra/environments/staging/variables.tf's note (hit live
  # there first).
  type    = string
  default = "calendar-dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# ===== Environment-tier knobs - see infra/modules/platform-addons/variables.tf
# for what each one actually controls. This file's defaults ARE this
# environment's real values (also mirrored in terraform.tfvars explicitly,
# so the tier's identity is visible without reading two files). =====

variable "karpenter_capacity_types" {
  type    = list(string)
  default = ["spot", "on-demand"]
}

variable "addon_replica_count" {
  type    = number
  default = 1
}

variable "rds_multi_az" {
  type    = bool
  default = false
}
