# RDS Postgres - the one piece of this stack whose data does NOT survive a
# destroy/recreate cycle (accepted trade-off, matches how the kind cluster's
# local Postgres is already treated - see workplan.txt Step 4 intro).
#
# Credentials: written directly into a Kubernetes Secret the app already
# expects (helm/calendar/charts/backend/values.yaml's existingSecret /
# existingSecretKey), deliberately WITHOUT AWS Secrets Manager - discussed
# explicitly in workplan.txt Step 4f. Secrets Manager's real value
# (rotation reaching the running app, multi-consumer sharing, audit trail)
# needs something to actually sync it into the cluster (External Secrets
# Operator), which doesn't exist yet; standing up Secrets Manager alone
# today would just be Terraform writing the password there and immediately
# reading it back out to populate this same Kubernetes Secret - no
# operational benefit, plus ongoing cost, for a stack destroyed every
# session. Revisit once the AI-integration work needs its first real static
# app secret (see workplan.txt note) - migrating this password into
# Secrets Manager + ESO at that point is a small, mechanical change, not a
# rearchitecture.

resource "random_password" "rds" {
  length  = 32
  special = false # avoid characters that need URL-encoding in a DATABASE_URL connection string
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "Allow Postgres from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"
  # Actual latest is 7.2.0 (checked via the registry API, not the bootcamp
  # reference's stale ~> 6.0 pin) - but 7.x requires the AWS provider >= 6.28,
  # a major-version jump from this project's existing `~> 5.0` pin (used by
  # the vpc/eks/karpenter modules too) that isn't worth forcing just for RDS.
  # 6.5.2 (latest 6.x) only needs AWS provider >= 5.36, already satisfied -
  # deliberately one minor version behind absolute latest for compatibility.
  version = "~> 6.0"

  identifier = "${var.cluster_name}-db"

  engine               = "postgres"
  engine_version       = "17.10" # checked actual available versions via `aws rds describe-db-engine-versions`, not assumed
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = var.rds_instance_class
  allocated_storage    = 20 # gp3 minimum for Postgres
  storage_type         = "gp3"
  storage_encrypted    = true

  db_name  = "calendar"
  username = "calendar"
  password = random_password.rds.result
  port     = 5432

  # Even in v6.x, this module defaults manage_master_user_password = true
  # (RDS natively managing the password in its own Secrets Manager secret) -
  # the plain `password` above is silently ignored unless this is explicitly
  # turned off. Real thing caught in the plan output (manage_master_user_password
  # showed true, password never appeared in the diff at all) before ever
  # applying - keeping the no-Secrets-Manager design decided in workplan.txt
  # Step 4f.
  manage_master_user_password = false

  multi_az            = var.rds_multi_az # false (dev, cost) or true (staging, HA demonstration) - see variables.tf
  publicly_accessible = false

  create_db_subnet_group = true
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Ephemeral by design - this whole stack is destroyed at the end of every
  # working session, so there is no point paying for automated backups, and
  # skipping the final snapshot keeps `terraform destroy` fast.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  # No enhanced monitoring / Performance Insights - extra cost with no real
  # payoff for a short-lived, low-traffic learning-project database.
  create_monitoring_role       = false
  performance_insights_enabled = false
}

# The Secret the backend chart already expects to exist (see
# helm/calendar/charts/backend/values.yaml: existingSecret/existingSecretKey).
# Written to the "default" namespace to match where the kind environment's
# ApplicationSet entry deploys the app today - a future EKS entry in
# argocd/applications/calendar-appset.yaml (deploying the actual app here,
# not yet done) would need to target this same namespace.
resource "kubernetes_secret" "calendar_db_credentials" {
  metadata {
    name      = "calendar-db-credentials"
    namespace = "default"
  }

  data = {
    DATABASE_URL = "postgresql://${module.rds.db_instance_username}:${random_password.rds.result}@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${module.rds.db_instance_name}"
  }

  type = "Opaque"
}
