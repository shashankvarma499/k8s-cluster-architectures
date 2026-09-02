variable "region" {
  description = "AWS region for the cluster and VPC."
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name. Also used as the karpenter.sh/discovery tag value."
  type        = string
  default     = "k8s-arch-eks"
}

variable "cluster_version" {
  description = "EKS Kubernetes version. 1.34 is in standard support through 2026-12-02 (https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)."
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "az_count" {
  description = "How many regional AZs to use for public + private subnets (2 or 3)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "If true, one shared NAT Gateway (cheaper labs). If false, one NAT per AZ (production HA)."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Required for local terraform/helm/kubectl without a VPN/bastion."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach a public API endpoint. Tighten this before any real workload."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  description = "Instance types for the managed node group that runs Karpenter, Cilium, and other system add-ons."
  type        = list(string)
  default     = ["m6i.large", "m5.large"]
}

variable "system_node_min_size" {
  description = "Minimum size of the system managed node group."
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum size of the system managed node group."
  type        = number
  default     = 3
}

variable "system_node_desired_size" {
  description = "Desired size of the system managed node group."
  type        = number
  default     = 2
}

variable "karpenter_version" {
  description = "Karpenter Helm chart / CRD version (oci://public.ecr.aws/karpenter). v1.14.1 is current LTS as of 2026-08-21."
  type        = string
  default     = "1.14.1"
}

variable "cilium_version" {
  description = "Cilium Helm chart version from https://helm.cilium.io/ (1.20.1 released 2026-08-18)."
  type        = string
  default     = "1.20.1"
}

variable "metrics_server_chart_version" {
  description = "metrics-server Helm chart version from https://kubernetes-sigs.github.io/metrics-server/."
  type        = string
  default     = "3.13.0"
}

variable "tags" {
  description = "Extra tags applied to every taggable resource."
  type        = map(string)
  default = {
    Environment = "lab"
    ManagedBy   = "terraform"
    Project     = "k8s-cluster-architectures"
  }
}
