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
  description = "Namespace to deploy Longhorn into."
  type        = string
  default     = "longhorn-system"
}

variable "create_namespace" {
  description = "Whether Terraform should create the namespace."
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "longhorn"
}

variable "chart_version" {
  description = "Version of the longhorn/longhorn chart to install."
  type        = string
  default     = "1.12.1"
}

variable "replica_count" {
  description = "Default number of replicas Longhorn keeps per volume. 3 matches the 3-node cluster so a single node can be lost without data loss."
  type        = number
  default     = 3
}

variable "default_data_path" {
  description = <<-EOT
    Path on each node's filesystem where Longhorn stores volume data.
    Uses the node's root filesystem, not the leftover unmounted data disks
    present on mf-095/mf-167 (see docs/longhorn.md) — those are left alone
    since they hold unidentified pre-rebuild data and mf-113 has no
    equivalent second disk.
  EOT
  type        = string
  default     = "/var/lib/longhorn"
}

variable "backup_target" {
  description = <<-EOT
    Default backup target for Longhorn volume backups. Points at the
    "longhorn-backups" NFS share on rasppi (see docs/rasppi.md). The path is
    the NFSv4 one: OMV exports /export as the v4 pseudo-root, so
    /export/longhorn-backups on the server is mounted as /longhorn-backups.
    Set to null to leave the backup target unset.
  EOT
  type        = string
  default     = "nfs://192.168.39.30:/longhorn-backups"
}

variable "set_default_storage_class" {
  description = <<-EOT
    Whether Longhorn's StorageClass should be marked as the cluster default.
    False by default so it does not conflict with k3s's built-in
    local-path-provisioner, which is already the default StorageClass.
    Set true only after also disabling local-path's default annotation.
  EOT
  type        = bool
  default     = false
}
