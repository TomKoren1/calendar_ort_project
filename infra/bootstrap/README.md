# Bootstrap infra

Creates the minimum AWS infrastructure CI needs to push images to ECR via OIDC, before any
"real" infra (VPC/EKS/RDS, see `workplan.txt` Step 4) exists:

- `calendar-backend` / `calendar-frontend` ECR repositories (scan-on-push, 10-image lifecycle policy)
- A GitHub Actions OIDC identity provider (account-wide, one-time)
- An IAM role only `push`-to-`main` workflow runs on this exact repo can assume, scoped to
  push-only permissions on just these two repositories

Deliberately uses **local Terraform state** (not S3) — this stack's job is partly to
provide the account with its first pieces of durable infra, so it can't depend on a remote
backend that would itself need bootstrapping. Everything from Step 4 onward uses remote state.

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
```

Requires AWS credentials configured locally (e.g. `aws configure` / `AWS_PROFILE`) with
permission to create IAM roles/policies, an IAM OIDC provider, and ECR repositories.
