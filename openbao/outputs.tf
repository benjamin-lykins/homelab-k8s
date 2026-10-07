output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.openbao.name
}

output "release_status" {
  value = helm_release.openbao.status
}

output "address" {
  description = "In-cluster address of the OpenBao server."
  value       = "http://${helm_release.openbao.name}.${var.namespace}.svc:8200"
}
