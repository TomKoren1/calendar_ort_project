output "configure_kubectl" {
  description = "Run this after apply to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}

output "ingress_nginx_hostname_command" {
  value = module.addons.ingress_nginx_hostname_command
}

output "grafana_admin_password" {
  value     = module.addons.grafana_admin_password
  sensitive = true
}

output "grafana_port_forward_command" {
  value = module.addons.grafana_port_forward_command
}
