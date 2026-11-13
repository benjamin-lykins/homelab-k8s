resource "kubernetes_namespace" "longhorn" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "longhorn" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.chart_version

  create_namespace = false

  set {
    name  = "defaultSettings.defaultReplicaCount"
    value = var.replica_count
  }

  set {
    name  = "defaultSettings.defaultDataPath"
    value = var.default_data_path
    type  = "string"
  }

  set {
    name  = "persistence.defaultClass"
    value = var.set_default_storage_class
  }

  set {
    name  = "persistence.defaultClassReplicaCount"
    value = var.replica_count
  }

  dynamic "set" {
    for_each = var.backup_target == null ? [] : [var.backup_target]
    content {
      name  = "defaultBackupStore.backupTarget"
      value = set.value
      type  = "string"
    }
  }

  depends_on = [kubernetes_namespace.longhorn]
}
