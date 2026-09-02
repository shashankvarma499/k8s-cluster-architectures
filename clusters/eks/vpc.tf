module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs = local.azs
  # /20 private (nodes, Karpenter, internal LBs), /24 public (NAT, ELB), /24 intra
  # (EKS control-plane ENIs). Layout matches the terraform-aws-eks karpenter example
  # so the three ranges never overlap inside a /16.
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]
  intra_subnets   = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # EKS subnet-discovery tags:
  # https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
  # https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

  tags = local.tags
}
