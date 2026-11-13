resource "helm_release" "csi_driver_nfs" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  version    = var.chart_version

  create_namespace = false

  # The chart can create a StorageClass itself; it's managed below instead so
  # its parameters are visible and versioned here.
  set {
    name  = "storageClass.create"
    value = false
  }
}

resource "kubernetes_storage_class_v1" "nfs" {
  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = tostring(var.set_default_storage_class)
    }
  }

  storage_provisioner    = "nfs.csi.k8s.io"
  reclaim_policy         = var.reclaim_policy
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true
  mount_options          = var.mount_options

  parameters = {
    server   = var.nfs_server
    share    = var.nfs_share
    onDelete = var.on_delete
  }

  depends_on = [helm_release.csi_driver_nfs]
}
