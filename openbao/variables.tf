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
  description = "Namespace to deploy OpenBao into."
  type        = string
  default     = "openbao"
}

variable "create_namespace" {
  description = "Whether Terraform should create the namespace."
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "openbao"
}

variable "chart_version" {
  description = "Version of the openbao/openbao chart to install."
  type        = string
  default     = "0.30.2"
}

variable "dev_root_token" {
  description = <<-EOT
    Root token the dev-mode server is started with. Dev mode is insecure by
    design (in-memory storage, auto-unsealed); override this in
    terraform.tfvars if the server is reachable by anything you don't trust.
  EOT
  type        = string
  default     = "root"
  sensitive   = true
}

variable "ui_enabled" {
  description = "Whether to create a Service for the OpenBao web UI."
  type        = bool
  default     = true
}

variable "injector_enabled" {
  description = "Whether to install the OpenBao agent sidecar injector."
  type        = bool
  default     = true
}
