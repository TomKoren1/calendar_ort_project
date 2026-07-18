output "configure_kubectl" {
  description = "Run this after apply to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}

output "ingress_nginx_hostname_command" {
  value = module.addons.ingress_nginx_hostname_command
}
