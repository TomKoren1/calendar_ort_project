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
  kube-proxy, vpc-cni, eks-pod-identity-agent). Karpenter (next piece) will provision all
  *application* workload compute on demand; its own controller pods run on a small Fargate profile
  rather than needing a permanent EC2 node group just to host them. There **is** one small EKS
  managed node group (`system`, 1x t3.small, on-demand) though - `kube-proxy`/`vpc-cni` are
  DaemonSets and cannot run on Fargate at all (a real AWS platform limitation hit during the first
  apply attempt: `coredns` timed out after 20 minutes with zero compute anywhere in the cluster).
  This node group is for core system pods only, separate from Karpenter's job of scaling actual
  application workloads. `cluster_endpoint_public_access = true` (still IAM-authenticated for any
  real API call) - a deliberate simplification for reaching the cluster from a home machine, not
  something a real org would leave wide open. After `apply`, run
  `terraform output -raw configure_kubectl | sh` (or copy the command it prints) to point `kubectl`
  at the new cluster.

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
terraform destroy # when done for the session
```
