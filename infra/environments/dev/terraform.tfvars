# dev: cost-optimized tier - the same values this stack used as infra/main/
# before this environment split. Spot-first Karpenter capacity, single-AZ RDS,
# single replica per addon. See infra/environments/README.md for the full
# dev-vs-staging comparison.

cluster_name             = "calendar-dev"
karpenter_capacity_types = ["spot", "on-demand"]
addon_replica_count      = 1
rds_multi_az             = false
