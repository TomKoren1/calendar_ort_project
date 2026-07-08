# Main infra: VPC, EKS, Karpenter, ALB controller, RDS

The "real" infra stack — VPC, EKS cluster, node autoscaling (Karpenter), AWS Load Balancer
Controller, CNI/CSI add-ons, and RDS. Built incrementally, piece by piece; this README will grow
with each piece.

**Deliberately meant to be applied and destroyed every working session**, not left running — an
always-on version of this stack costs roughly $150-300+/month (EKS control plane, NAT gateway,
worker nodes, RDS, ALB). Cost-optimized choices are made throughout specifically because of this
(single NAT gateway, single-AZ RDS, small/spot instances) — see inline comments for each one and
`workplan.txt` Step 4 for the full reasoning.

Uses the **real remote backend** created once in `infra/state-backend/` (S3 + DynamoDB) — that
backend must already exist and must never be destroyed, even though this stack is destroyed
regularly. See that module's own README.

RDS data does **not** survive a destroy/recreate cycle (by design, accepted trade-off — same
throwaway treatment as the kind cluster's local Postgres).

## Pieces built so far

- **VPC** (`vpc.tf`): `terraform-aws-modules/vpc`, 2 AZs, public + private subnets, single NAT
  gateway. Subnets carry the specific tags EKS/the ALB controller/Karpenter need to auto-discover
  them (`kubernetes.io/cluster/<name>`, `kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`,
  `karpenter.sh/discovery`) - set now even though EKS/Karpenter themselves come in later pieces.
  Every component (subnets, IGW, NAT gateway + EIP, route tables, default SG) has its own explicit
  name - several resources default to sharing the VPC's own generic name otherwise.
- **EKS cluster** (`eks.tf`): `terraform-aws-modules/eks`, control plane + 4 addons (coredns,
  kube-proxy, vpc-cni, eks-pod-identity-agent), plus one small EKS managed node group (`system`,
  1x t3.small, on-demand) dedicated to core system pods. No Fargate here - `kube-proxy`/`vpc-cni`
  are DaemonSets and cannot run on Fargate at all (a real AWS platform limitation hit during the
  first apply attempt: `coredns` timed out after 20 minutes with zero compute anywhere in the
  cluster). `cluster_endpoint_public_access = true` (still IAM-authenticated for any real API call) -
  a deliberate simplification for reaching the cluster from a home machine, not something a real org
  would leave wide open. After `apply`, run `terraform output -raw configure_kubectl | sh` (or copy
  the command it prints) to point `kubectl` at the new cluster.
- **Karpenter** (`karpenter.tf`): provisions compute for *application* workloads only (the calendar
  app, once deployed) - core system pods stay on the fixed `system` node group above, not migrated
  onto Karpenter-managed nodes. One simplified `general-purpose` NodePool (spot-first, small
  `t`-family instances) instead of the bootcamp reference stack's four specialized pools - this app
  has no exotic compute needs. Real, multi-part debugging trail worth knowing about if this piece
  ever needs touching again (full detail in `workplan.txt` Step 4d and this project's saved
  memories): `EC2NodeClass` needs `amiSelectorTerms` explicitly (Karpenter's `v1` API, unlike the
  older `v1beta1`); Karpenter's own controller **cannot run on a Fargate profile** here (real,
  persistent STS/DNS connectivity failures - schedules on the `system` node group instead, and
  removing the Fargate profile was required, not optional, since a Fargate profile claims every pod
  in a matching namespace with no per-pod opt-out); the chart version must be checked against what's
  actually current (`helm show chart oci://public.ecr.aws/karpenter/karpenter`) rather than trusted
  from reference material, since an old pinned version outright refuses to start against a newer
  Kubernetes version; and the Helm chart module's own default controller IAM policy needed a
  supplementary policy (EC2 describe actions, instance-profile management, PassRole) to actually
  function.

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
terraform destroy # when done for the session
```
