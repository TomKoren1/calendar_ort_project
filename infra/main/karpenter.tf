# Karpenter provisions compute for APPLICATION workloads only (backend/
# frontend pods) - core system pods (coredns/kube-proxy/vpc-cni) already run
# on the fixed "system" EKS managed node group from eks.tf, so there's no
# need to migrate them onto Karpenter-provisioned nodes at all.

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  create_node_iam_role          = true
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"

  # Simplification vs. a real prod setup: no spot-interruption SQS queue.
  # A reclaimed spot node just gets rescheduled - a minor blip, not a real
  # availability concern for a short-lived, destroy-per-session cluster.
  enable_spot_termination = false
}

# The module's own default controller IAM policy turned out incomplete for
# this Karpenter version - real errors hit live: "no subnets found" and an
# explicit `iam:ListInstanceProfiles` AccessDenied. This is the standard set
# of permissions Karpenter's docs/the bootcamp reference stack use for the
# controller role; kept broad (not resource-tag-scoped like a hardened prod
# policy would be) since getting it working correctly matters more than
# maximal least-privilege for this learning project.
data "aws_iam_policy_document" "karpenter_controller_extra" {
  statement {
    sid = "AllowRegionalReadActions"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSpotPriceHistory",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowSSMReadActions"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}::parameter/aws/service/*"]
  }

  statement {
    sid       = "AllowPricingReadActions"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid = "AllowInstanceProfileActions"
    actions = [
      "iam:ListInstanceProfiles",
      "iam:GetInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowPassingInstanceRole"
    actions   = ["iam:PassRole"]
    resources = [module.karpenter.node_iam_role_arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowAPIServerEndpointDiscovery"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_policy" "karpenter_controller_extra" {
  name_prefix = "KarpenterControllerExtra-"
  policy      = data.aws_iam_policy_document.karpenter_controller_extra.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_extra" {
  role       = module.karpenter.iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_extra.arn
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  # 1.1.1 (matching the bootcamp reference stack) panics on startup -
  # "karpenter version is not compatible with K8s version 1.36" (this EKS
  # cluster's version is newer than that chart release supports). Omitting
  # version entirely does NOT force an upgrade on an existing release
  # (Terraform's helm provider leaves an already-installed version alone) -
  # confirmed via `helm show chart oci://public.ecr.aws/karpenter/karpenter`
  # that 1.13.0 is the current latest and pinning to it explicitly instead.
  version = "1.13.0"
  wait    = true

  values = [
    yamlencode({
      settings = {
        clusterName     = module.eks.cluster_name
        clusterEndpoint = module.eks.cluster_endpoint
      }
      serviceAccount = {
        name = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter.iam_role_arn
        }
      }
      replicas = 1 # single controller replica - fine for a small, short-lived cluster
      # Explicit modest requests - the chart's own defaults are sized for a
      # bigger node than our t3.small system node group, which also hosts
      # coredns/kube-proxy/vpc-cni/eks-pod-identity-agent.
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}

resource "kubectl_manifest" "ec2_node_class_default" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      # amiSelectorTerms is required in Karpenter's v1 API (unlike the older
      # v1beta1 API, where amiFamily alone was enough to implicitly resolve
      # an AMI) - hit as a real error on the first apply attempt.
      amiSelectorTerms = [
        { alias = "al2023@latest" }
      ]
      role = module.karpenter.node_iam_role_name
      subnetSelectorTerms = [{
        tags = { "karpenter.sh/discovery" = var.cluster_name }
      }]
      securityGroupSelectorTerms = [{
        tags = { "karpenter.sh/discovery" = var.cluster_name }
      }]
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "node_pool_general" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "general-purpose"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            # Cost-optimized: spot first (falls back to on-demand if none
            # available), small/cheap instance sizes only - matches this
            # whole stack's apply-and-destroy-per-session design.
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["t"] },
            { key = "karpenter.k8s.aws/instance-size", operator = "In", values = ["small", "medium"] },
          ]
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  })

  depends_on = [kubectl_manifest.ec2_node_class_default]
}
