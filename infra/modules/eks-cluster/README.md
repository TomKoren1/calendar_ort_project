# Module: eks-cluster

VPC (`terraform-aws-modules/vpc`) + EKS cluster (`terraform-aws-modules/eks`)
with one small fixed managed node group (`system`, 1x t3.small, on-demand)
for core system pods (coredns/kube-proxy/vpc-cni - DaemonSets, which cannot
run on Fargate at all). Application workload scaling is handled separately by
Karpenter, in the `platform-addons` module.

Only needs the `aws` provider - no circular dependency on its own outputs, so
it can always be applied first (`terraform apply -target module.cluster`) from
empty state. See `infra/environments/README.md` for why that matters.

## Inputs

| Name | Description | Default |
|---|---|---|
| `cluster_name` | EKS cluster name, used for subnet auto-discovery tags too | *(required)* |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `azs` | Availability zones to spread subnets across | `["us-east-1a", "us-east-1b"]` |

## Outputs

`vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `vpc_cidr_block`,
`cluster_name`, `cluster_arn`, `cluster_endpoint`,
`cluster_certificate_authority_data`, `oidc_provider`, `oidc_provider_arn`,
`cluster_security_group_id`, `node_security_group_id` - consumed by the
`platform-addons` module and by the calling environment's `provider.tf`
(to configure the helm/kubectl/kubernetes providers).
