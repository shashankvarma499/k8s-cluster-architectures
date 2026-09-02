variable "cluster_name" {
  description = "EKS cluster name (used in Cilium cluster.name)."
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint URL (https://...)."
  type        = string
}

variable "cilium_version" {
  description = "Cilium Helm chart version."
  type        = string
}

variable "metrics_server_chart_version" {
  description = "metrics-server Helm chart version."
  type        = string
}
