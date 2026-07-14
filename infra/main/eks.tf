module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name = var.cluster_name
  # cluster_version intentionally omitted - lets AWS use its current default
  # supported version instead of a version pinned here going stale over time.

  # Open to the internet (still IAM-authenticated for any actual API call) -
  # the pragmatic choice for a personal learning cluster reached from a home
  # machine with a changing IP. A real org would restrict this via
  # cluster_endpoint_public_access_cidrs, or go private-only behind a VPN/
  # bastion - a deliberate simplification, not an oversight.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Whoever runs `terraform apply` (the terraform-bootstrap IAM user) gets
  # cluster-admin automatically - needed to actually kubectl into this
  # afterward without a separate IAM-to-RBAC mapping step.
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  # manage_aws_auth_configmap: removed from this module version (was in the
  # bootcamp reference stack's older version) - API_AND_CONFIG_MAP mode plus
  # enable_cluster_creator_admin_permissions above still gets kubectl access
  # via the newer EKS Access Entries API without needing this explicitly.

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    # Added for Step 6 HPA support - without this, HorizontalPodAutoscaler
    # resources just show <unknown> targets forever (no Metrics API for
    # them to read from). Confirmed available as a real EKS-managed addon
    # via `aws eks describe-addon-versions --addon-name metrics-server`
    # before adding, not assumed.
    metrics-server = {
      most_recent = true
    }
  }

  # Real correction made after the first apply attempt: originally planned
  # zero EKS managed node groups at all (Karpenter provisions everything).
  # That doesn't work for core cluster system pods specifically -
  # kube-proxy/vpc-cni are DaemonSets, which CANNOT run on Fargate at all
  # (an AWS platform limitation, not a config issue), and the coredns addon
  # timed out after 20 minutes stuck DEGRADED waiting for compute that never
  # existed. A tiny, fixed system node group (not Karpenter-managed) is the
  # standard fix - Karpenter still handles all actual application workload
  # scaling, this just hosts the handful of pods every cluster needs
  # regardless of Karpenter's existence.
  #
  # Second correction, same theme: originally gave Karpenter's own controller
  # a small Fargate profile to run on. That controller pod then crash-looped
  # on Fargate specifically - DNS lookups for sts.us-east-1.amazonaws.com
  # (needed for its IRSA credentials) consistently timed out, a real Fargate
  # networking issue, not a config mistake (security groups/routing all
  # checked out fine). Removed the Fargate profile entirely; Karpenter's
  # controller now schedules onto this same system node group instead, which
  # already has proven-working networking (it successfully pulls from ECR).
  eks_managed_node_groups = {
    system = {
      name           = "${var.cluster_name}-system"
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND" # reliability over spot's interruption risk for core system pods
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      subnet_ids     = module.vpc.private_subnets
    }
  }

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# The EKS module doesn't expose a tags input for the cluster/node security
# groups it creates itself - tag them directly so Karpenter (next piece) can
# find them via the same discovery mechanism used for the VPC's subnets.
resource "aws_ec2_tag" "cluster_security_group_karpenter" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "node_security_group_karpenter" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
