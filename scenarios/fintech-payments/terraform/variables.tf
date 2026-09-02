variable "region" {
  description = "Primary AWS region for the cluster and VPC."
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "Region that receives the Velero bucket replica. Restore is documented in runbooks/disaster-recovery.md."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name. Also used as the karpenter.sh/discovery tag value."
  type        = string
  default     = "northstar-payments"
}

variable "cluster_version" {
  description = "EKS Kubernetes version. 1.34 is in standard support through 2026-12-02 (https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)."
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC. Distinct from the clusters/eks lab CIDR (10.42.0.0/16)."
  type        = string
  default     = "10.64.0.0/16"
}

variable "az_count" {
  description = "How many regional AZs to use for public + private + intra subnets. Production is 3."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "If true, one shared NAT Gateway (never for production CDE). If false, one NAT per AZ."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Production PCI clusters should set this false and use a VPN/bastion."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach a public API endpoint. Lock this to office/VPN before real traffic."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  description = "Instance types for the managed node group that runs Karpenter, Cilium, and other system add-ons."
  type        = list(string)
  default     = ["m6i.large", "m5.large"]
}

variable "system_node_min_size" {
  description = "Minimum size of the system managed node group. 3 keeps Karpenter up during an AZ loss."
  type        = number
  default     = 3
}

variable "system_node_max_size" {
  description = "Maximum size of the system managed node group."
  type        = number
  default     = 4
}

variable "system_node_desired_size" {
  description = "Desired size of the system managed node group."
  type        = number
  default     = 3
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

variable "enable_vpc_endpoints" {
  description = "Create Gateway/Interface VPC endpoints for S3, ECR, STS, KMS, Logs, EC2, EKS so CDE egress need not traverse NAT."
  type        = bool
  default     = true
}

variable "velero_backup_expiration_days" {
  description = "Noncurrent version expiration on the Velero bucket (object lifecycle). Hourly backups have a 30-day TTL in Velero itself."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Extra tags applied to every taggable resource."
  type        = map(string)
  default = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Project     = "northstar-payments"
    PCIScope    = "connected-to-cde"
  }
}
