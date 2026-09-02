# Production EKS 1.34. Pattern matches clusters/eks (terraform-aws-modules/eks/aws
# ~> 20.37) with PCI-flavored extras: KMS secrets encryption, 3-AZ system MNG,
# all control-plane log types, 365-day audit retention.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  enable_irsa = true

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
  cloudwatch_log_group_retention_in_days = 365
  cloudwatch_log_group_kms_key_id        = aws_kms_key.audit.arn

  # Module-managed CMK for Kubernetes Secrets (PCI Req. 3 defense-in-depth).
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/20.37.1
  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # vpc-cni is installed first so the managed node group can become Ready in a
  # single terraform apply. Cilium is then chained on top (addons/) to provide
  # eBPF NetworkPolicy / Hubble. Full ENI-mode replacement is a second-pass
  # migration; see https://docs.cilium.io/en/stable/installation/k8s-install-helm/
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
    snapshot-controller = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    system = {
      name           = "${var.cluster_name}-system"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.system_node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.system_node_min_size
      max_size     = var.system_node_max_size
      desired_size = var.system_node_desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        "karpenter.sh/controller" = "true"
        workload                  = "system"
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # Exactly one security group in the account should carry this tag so
  # Karpenter's EC2NodeClass can discover it.
  # https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/
  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })

  tags = local.tags
}

module "addons" {
  source = "./addons"

  cluster_name                 = module.eks.cluster_name
  cluster_endpoint             = module.eks.cluster_endpoint
  cilium_version               = var.cilium_version
  metrics_server_chart_version = var.metrics_server_chart_version

  depends_on = [module.eks]
}
