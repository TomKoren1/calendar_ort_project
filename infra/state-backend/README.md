# Terraform state backend

Creates the S3 bucket + DynamoDB lock table that `infra/main/` (VPC/EKS/Karpenter/RDS) uses as
its **remote** Terraform backend.

**Apply this once. Never destroy it**, even though `infra/main/` is designed to be applied and
destroyed repeatedly to control cost (see `infra/main/README.md`). If this bucket/table ever went
away, every future `terraform apply` in `infra/main/` would have no record of what it previously
created - a real risk of duplicate or orphaned AWS resources. Both resources have
`lifecycle { prevent_destroy = true }` as a guard against exactly that mistake; `terraform destroy`
here will refuse until that's deliberately removed.

Uses **local** state itself (not the backend it creates) - same bootstrap chicken-and-egg reasoning
as `infra/bootstrap/`: it can't depend on a remote backend it's the one creating.

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
terraform output  # bucket/table names needed by infra/main/'s backend config
```
