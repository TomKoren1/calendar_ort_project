output "ingress_nginx_hostname_command" {
  description = "Run this after apply to get the NLB hostname to reach the app at"
  value       = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "grafana_port_forward_command" {
  description = "Run this after apply, then open http://localhost:3000 (admin / see grafana_admin_password output)"
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}
