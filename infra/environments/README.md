# Environments: dev, staging

Two independently-applied environments, each a thin caller of the same two
shared modules (`infra/modules/eks-cluster/`, `infra/modules/platform-addons/`).
Replaces the old flat `infra/main/` stack - see `workplan.txt` Step 4g for why.

**Deliberately meant to be applied and destroyed every working session**, not
left running - an always-on version of either environment costs roughly
$150-300+/month (EKS control plane, NAT gateway, worker nodes, RDS, ALB/NLB).
**Never apply both environments at once** - there's no cost or technical reason
to; the point is to demonstrate the environment-separation pattern, not to run
two live clusters. Apply one, verify, destroy, then apply the other if needed.

Both share the same remote backend (`infra/state-backend/`'s S3 bucket, with
native S3 locking via `use_lockfile` - no separate DynamoDB table),
distinguished only by state `key` (`environments/dev/terraform.tfstate` vs
`environments/staging/terraform.tfstate`) - that backend must already exist
and must never be destroyed. See that module's own README.

RDS data does **not** survive a destroy/recreate cycle in either environment
(by design, accepted trade-off - same throwaway treatment as the kind
cluster's local Postgres).

## dev vs staging

| Variable | dev (cost-optimized) | staging (more production-like) |
|---|---|---|
| `cluster_name` | `calendar-dev` | `calendar-stg` (kept short - see variables.tf, the EKS node-group IAM role name_prefix has a 38-char AWS limit) |
| Karpenter capacity type | `["spot", "on-demand"]` | `["on-demand"]` (no spot-interruption risk) |
| RDS `multi_az` | `false` | `true` (real failover) |
| Addon replica count (ALB controller, ingress-nginx, Karpenter) | `1` | `2` (basic HA) |

Everything else (VPC CIDR, AZ count, single NAT gateway, RDS instance class,
node instance types) is identical between the two - kept intentionally small,
just enough to demonstrate a genuine environment-tier difference without
inventing complexity neither environment actually needs.

## Why there's still some duplication

Each environment has its own `provider.tf` (~35 lines, near-identical between
dev/staging). This is not an oversight - Terraform provider blocks must live
in the calling root, not in a shared module, so this is the one piece plain
Terraform genuinely cannot deduplicate. This is exactly the kind of
duplication [Terragrunt](https://terragrunt.gruntwork.io/)'s `generate` block
exists to template away - deliberately not adopted here, since the bootcamp
material frames Terragrunt as solving pain from 3+ near-identical
environments, and reaching for it before that pain exists as its own
documented anti-pattern. Revisit if a third environment is ever added.

## Usage

```bash
cd infra/environments/dev/   # or staging/

terraform init

# Phased apply required from empty state: the helm/kubectl/kubernetes
# provider blocks in provider.tf depend on module.cluster's own outputs
# (cluster_endpoint, etc.), which can't be "known after apply" for a
# provider block the way a normal resource argument can.
terraform apply -target module.cluster
terraform apply                          # everything else

terraform output -raw configure_kubectl | sh   # point kubectl at the new cluster
terraform destroy                              # when done for the session
```
