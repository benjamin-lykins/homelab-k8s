variable "kubeconfig_path" {
  description = "Path to the kubeconfig file used to reach the cluster."
  type        = string
  default     = "homelab.yaml"
}

variable "kube_context" {
  description = "kubeconfig context to use. Null uses the current context."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace to deploy n8n into."
  type        = string
  default     = "n8n"
}

variable "image" {
  description = "n8n container image. Pinned to a version rather than :stable so upgrades are explicit."
  type        = string
  default     = "docker.n8n.io/n8nio/n8n:2.47.7"
}

variable "storage_class_name" {
  description = <<-EOT
    StorageClass for n8n's data volume (/home/node/.n8n: SQLite DB, config,
    binary data). Longhorn gives a replicated RWO block volume, so the pod can
    reschedule to any node. Avoid "nfs" here: SQLite over NFS is unreliable.
  EOT
  type        = string
  default     = "longhorn"
}

variable "storage_size" {
  description = "Size of n8n's data volume."
  type        = string
  default     = "5Gi"
}

variable "host" {
  description = <<-EOT
    Hostname the Traefik Ingress answers on. The default uses nip.io, which
    resolves to the embedded IP (the control-plane VIP), so no local DNS entry
    is needed. Also used for n8n's editor/webhook URLs.
  EOT
  type        = string
  default     = "n8n.192.168.39.20.nip.io"
}

variable "timezone" {
  description = "Timezone used by n8n's Schedule/Cron nodes."
  type        = string
  default     = "America/New_York"
}
