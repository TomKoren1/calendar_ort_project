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

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
terraform destroy # when done for the session
```
