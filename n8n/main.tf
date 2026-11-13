resource "kubernetes_namespace" "n8n" {
  metadata {
    name = var.namespace
  }
}

# n8n encrypts stored credentials with this key. It must stay stable for the
# life of the data volume; losing it makes saved credentials unreadable.
# It lives in Terraform state (already treated as secret).
resource "random_password" "encryption_key" {
  length  = 48
  special = false
}

resource "kubernetes_secret_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  data = {
    N8N_ENCRYPTION_KEY = random_password.encryption_key.result
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = "n8n-data"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  wait_until_bound = false
}

resource "kubernetes_deployment_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
    labels    = { app = "n8n" }
  }

  spec {
    # Single instance on SQLite; Recreate so the old pod releases the RWO
    # volume before the new one starts.
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = { app = "n8n" }
    }

    template {
      metadata {
        labels = { app = "n8n" }
      }

      spec {
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        container {
          name  = "n8n"
          image = var.image

          port {
            name           = "http"
            container_port = 5678
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.n8n.metadata[0].name
            }
          }

          env {
            name  = "N8N_HOST"
            value = var.host
          }
          env {
            name  = "N8N_PORT"
            value = "5678"
          }
          env {
            name  = "N8N_PROTOCOL"
            value = "http"
          }
          env {
            name  = "WEBHOOK_URL"
            value = "http://${var.host}/"
          }
          # Served over plain HTTP on the LAN, so the auth cookie can't be
          # marked Secure or browsers would drop it.
          env {
            name  = "N8N_SECURE_COOKIE"
            value = "false"
          }
          env {
            name  = "GENERIC_TIMEZONE"
            value = var.timezone
          }
          env {
            name  = "TZ"
            value = var.timezone
          }
          env {
            name  = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
            value = "true"
          }
          env {
            name  = "N8N_DIAGNOSTICS_ENABLED"
            value = "false"
          }

          volume_mount {
            name       = "data"
            mount_path = "/home/node/.n8n"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            period_seconds = 10
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            initial_delay_seconds = 60
            period_seconds        = 20
            failure_threshold     = 5
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    selector = { app = "n8n" }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "n8n" {
  metadata {
    name      = "n8n"
    namespace = kubernetes_namespace.n8n.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.n8n.metadata[0].name
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}
