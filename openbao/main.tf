resource "kubernetes_namespace" "openbao" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "openbao" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  version    = var.chart_version

  create_namespace = false

  # Dev mode: single in-memory server, auto-initialized and unsealed, with a
  # fixed root token. All data is lost when the pod restarts.
  set {
    name  = "server.dev.enabled"
    value = true
  }

  set_sensitive {
    name  = "server.dev.devRootToken"
    value = var.dev_root_token
    type  = "string"
  }

  set {
    name  = "ui.enabled"
    value = var.ui_enabled
  }

  set {
    name  = "injector.enabled"
    value = var.injector_enabled
  }

  depends_on = [kubernetes_namespace.openbao]
}
