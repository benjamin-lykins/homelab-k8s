output "release_name" {
  value = helm_release.csi_driver_nfs.name
}

output "release_status" {
  value = helm_release.csi_driver_nfs.status
}

output "storage_class_name" {
  value = kubernetes_storage_class_v1.nfs.metadata[0].name
}
