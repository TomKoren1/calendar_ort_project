# Module: platform-addons

Karpenter (application-workload node autoscaling), AWS Load Balancer
Controller + ingress-nginx (NLB in IP-target mode, Layer 7 routing on top),
and RDS Postgres. Everything here depends on an already-existing cluster's
outputs, passed in as plain input variables (not a `terraform_remote_state`
lookup - both modules are called from the same root in the same apply, see
`infra/environments/*/main.tf`).

Requires the `helm`, `kubectl`, and `kubernetes` providers to already be
configured by the calling root, using the `eks-cluster` module's outputs -
this module does not and cannot configure its own providers (Terraform
provider blocks must live in the root). This is why the calling environment
needs a phased apply (`-target module.cluster` first): see
`infra/environments/README.md`.

## Inputs

Cluster identity/network passthrough (all required, sourced from the
`eks-cluster` module's outputs): `aws_region`, `cluster_name`, `cluster_arn`,
`cluster_endpoint`, `vpc_id`, `private_subnet_ids`, `node_security_group_id`,
`oidc_provider`, `oidc_provider_arn`.

Environment-tier knobs (the actual dev-vs-staging differences - see
`infra/environments/README.md`):

| Name | Description | Default |
|---|---|---|
| `karpenter_capacity_types` | Karpenter NodePool capacity types | `["spot", "on-demand"]` |
| `karpenter_instance_sizes` | Karpenter NodePool allowed instance sizes | `["small", "medium"]` |
| `addon_replica_count` | Replica count for ALB controller / ingress-nginx / Karpenter controller | `1` |
| `rds_instance_class` | RDS instance class | `db.t4g.micro` |
| `rds_multi_az` | Whether RDS runs Multi-AZ | `false` |

## Outputs

`ingress_nginx_hostname_command` (run after apply to get the NLB hostname),
`rds_endpoint`.
