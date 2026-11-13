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
  description = "Namespace for the CSI driver (upstream recommends kube-system)."
  type        = string
  default     = "kube-system"
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "csi-driver-nfs"
}

variable "chart_version" {
  description = "Version of the csi-driver-nfs/csi-driver-nfs chart to install."
  type        = string
  default     = "4.13.6"
}

variable "storage_class_name" {
  description = "Name of the StorageClass PVCs use to request NFS-backed volumes."
  type        = string
  default     = "nfs"
}

variable "nfs_server" {
  description = "NFS server address: rasppi's wired NIC (see docs/rasppi.md)."
  type        = string
  default     = "192.168.39.30"
}

variable "nfs_share" {
  description = <<-EOT
    Exported path on the NFS server. Each PV gets its own subdirectory under it.
    This is the NFSv4 path: OMV exports /export as the v4 pseudo-root (fsid=0),
    so the "k8s" shared folder (/export/k8s on the server) is mounted as /k8s.
  EOT
  type        = string
  default     = "/k8s"
}

variable "mount_options" {
  description = "NFS mount options for volumes in this StorageClass."
  type        = list(string)
  default     = ["nfsvers=4.2", "hard"]
}

variable "reclaim_policy" {
  description = "What happens to a PV when its PVC is deleted (Delete or Retain)."
  type        = string
  default     = "Delete"
}

variable "on_delete" {
  description = <<-EOT
    What the driver does with a volume's directory when the PV is deleted
    (only applies when reclaim_policy = "Delete"): "delete", "retain", or
    "archive". The default, "archive", renames the directory to
    archived-<name> instead of removing it, so deleting a PVC by mistake loses
    no data. Clean up archived-* directories on the NAS by hand.
  EOT
  type        = string
  default     = "archive"
}

variable "set_default_storage_class" {
  description = "Whether this StorageClass is the cluster default. False: local-path stays the default."
  type        = bool
  default     = false
}
