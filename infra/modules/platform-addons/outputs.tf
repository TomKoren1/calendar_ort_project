output "ingress_nginx_hostname_command" {
  description = "Run this after apply to get the NLB hostname to reach the app at"
  value       = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}
