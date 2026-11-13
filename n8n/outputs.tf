output "namespace" {
  value = kubernetes_namespace.n8n.metadata[0].name
}

output "url" {
  description = "n8n editor URL."
  value       = "http://${var.host}/"
}

output "in_cluster_address" {
  value = "http://${kubernetes_service_v1.n8n.metadata[0].name}.${kubernetes_namespace.n8n.metadata[0].name}.svc"
}
