# staging: the "more production-like" tier - on-demand-only Karpenter
# capacity (no spot-interruption risk), Multi-AZ RDS (real failover), 2
# replicas per addon (basic HA). See infra/environments/README.md for the
# full dev-vs-staging comparison.

cluster_name             = "calendar-stg"
karpenter_capacity_types = ["on-demand"]
addon_replica_count      = 2
rds_multi_az             = true
