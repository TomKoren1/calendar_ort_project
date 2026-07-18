# kube-prometheus-stack: Prometheus + Alertmanager + Grafana + node-exporter
# (DaemonSet) + kube-state-metrics, bundled as one Helm chart - see
# workplan.txt Step 5. Deploy mechanism (Terraform, not Argo CD) decided
# explicitly with the user: matches every other platform addon in this file
# (Karpenter, AWS Load Balancer Controller, ingress-nginx), unlike the
# calendar app itself which is Argo CD-managed because it changes on every
# CI push - this stack doesn't change with app code, it's part of the
# cluster's baseline the same way Karpenter is.
#
# No IAM policy/IRSA needed here, unlike Karpenter/ALB controller above -
# Prometheus only talks to the Kubernetes API (in-cluster RBAC via its own
# ServiceAccount, provisioned by the chart itself), never AWS APIs directly.

resource "random_password" "grafana_admin" {
  length  = 24
  special = false # avoid characters that complicate copy/paste from `terraform output`
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  # Bootcamp reference material pinned 57.0.0 - checked actual current via
  # `helm search repo prometheus-community/kube-prometheus-stack --versions`:
  # 87.17.0.
  version = "87.17.0"
  wait    = true
  # This chart installs far more than ingress-nginx/Karpenter (CRDs, operator,
  # Prometheus, Alertmanager, Grafana, node-exporter DaemonSet, kube-state-
  # metrics) - the default 300s wait timeout is tight for that much at once.
  timeout = 600

  values = [
    yamlencode({
      # No PersistentVolumes for Prometheus/Grafana - consistent with this
      # stack's existing ephemeral-by-design posture (RDS skips backups and
      # the final snapshot too, see rds.tf) since the whole environment is
      # destroyed at the end of every working session anyway. Metrics/
      # dashboards created during a session don't need to survive it.
      prometheus = {
        prometheusSpec = {
          retention = "3d" # short-lived cluster - no need for the chart's 10d default
          resources = {
            requests = { cpu = "200m", memory = "512Mi" }
            limits   = { memory = "1Gi" }
          }
          # Pick up ServiceMonitor/PodMonitor CRDs anywhere in the cluster,
          # not just ones carrying this Helm release's own label - needed
          # once the app's own ServiceMonitor (a later Step 5 piece, added to
          # the calendar Helm chart, not this one) exists.
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { memory = "128Mi" }
          }
        }
      }

      grafana = {
        adminPassword = random_password.grafana_admin.result
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { memory = "256Mi" }
        }
        persistence = { enabled = false }
      }

      # node-exporter and kube-state-metrics run fine on the chart's own
      # small defaults at this cluster's scale - no override needed. Any
      # extra scheduling pressure from this whole stack is exactly what
      # Karpenter (karpenter.tf) exists to absorb by provisioning more
      # node capacity, not something to hand-tune requests around.
    })
  ]
}
