locals {
  # EKS/ALB-controller/Karpenter all discover which subnets to use via these
  # specific tag keys, not via config passed to the cluster itself - get them
  # right here once rather than debugging a missing-subnet issue later.
  cluster_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Explicit per-resource names - without these, several resources default to
  # sharing the VPC's own "Name" tag (e.g. the VPC and its Internet Gateway
  # both showing "calendar-eks-vpc"), which is hard to tell apart in the AWS
  # console/CLI output.
  public_subnet_names         = [for az in var.azs : "${var.cluster_name}-public-${az}"]
  private_subnet_names        = [for az in var.azs : "${var.cluster_name}-private-${az}"]
  igw_tags                    = { Name = "${var.cluster_name}-igw" }
  nat_gateway_tags            = { Name = "${var.cluster_name}-nat" }
  nat_eip_tags                = { Name = "${var.cluster_name}-nat-eip" }
  public_route_table_tags     = { Name = "${var.cluster_name}-public-rt" }
  private_route_table_tags    = { Name = "${var.cluster_name}-private-rt" }
  default_security_group_name = "${var.cluster_name}-default-sg"

  enable_nat_gateway = true
  # Cost-optimized choice for this apply-and-destroy-per-session stack: one
  # NAT gateway shared across AZs, not one per AZ. A real always-on prod
  # setup would want per-AZ NAT gateways so a single AZ outage doesn't take
  # out egress for the whole cluster - not a concern for a cluster that's
  # only up for the length of a working session. Same for both dev and
  # staging environments here - the tier difference this project actually
  # demonstrates is capacity-type/multi-AZ RDS/replica counts, not NAT HA.
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/elb" = 1 # ALB controller: internet-facing load balancers go here
  })

  private_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/internal-elb" = 1                # ALB controller: internal load balancers go here
    "karpenter.sh/discovery"          = var.cluster_name # Karpenter: which subnets it's allowed to launch nodes into
  })
}
