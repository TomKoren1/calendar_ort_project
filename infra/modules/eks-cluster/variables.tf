variable "cluster_name" {
  description = "EKS cluster name - used for VPC subnet auto-discovery tags and the EKS module itself"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across. 2 is enough for EKS's minimum requirement and basic redundancy while this stack is up - not the 3 a long-running prod setup would use, matching the cost-optimized/apply-and-destroy-per-session design of this whole stack."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
