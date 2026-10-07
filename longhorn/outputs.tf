output "namespace" {
  value = var.namespace
}

output "release_name" {
  value = helm_release.longhorn.name
}

output "release_status" {
  value = helm_release.longhorn.status
}
