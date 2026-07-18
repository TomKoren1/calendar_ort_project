# Terraform state backend

Creates the S3 bucket that `infra/environments/dev/` and `infra/environments/staging/`
(VPC/EKS/Karpenter/RDS, one per environment - see `infra/environments/README.md`) share as their
**remote** Terraform backend, each with its own state `key`.

Locking uses Terraform's native S3 locking (`use_lockfile = true` in each environment's `backend
"s3"` block, Terraform 1.10+) rather than a separate DynamoDB table - an atomic conditional
`PutObject` (`If-None-Match`) creates a companion `.tflock` object next to the state file, and
fails if one already exists. This is the currently-recommended approach and needs nothing
provisioned here; it's purely a client-side backend setting. Not to be confused with **S3 Object
Lock**, a different, unrelated bucket feature (WORM/compliance retention) that would actively get
in the way here by preventing state file overwrites.

**Apply this once. Never destroy it**, even though both environments under `infra/environments/`
are designed to be applied and destroyed repeatedly to control cost. If this bucket ever went
away, a future `terraform apply` in either environment would have no record of what it previously
created - a real risk of duplicate or orphaned AWS resources. It has `lifecycle { prevent_destroy
= true }` as a guard against exactly that mistake; `terraform destroy` here will refuse until
that's deliberately removed.

Uses **local** state itself (not the backend it creates) - same bootstrap chicken-and-egg reasoning
as `infra/bootstrap/`: it can't depend on a remote backend it's the one creating.

```
terraform init
terraform plan
terraform apply   # only after reviewing the plan output
terraform output  # bucket name needed by each environment's backend config
```
