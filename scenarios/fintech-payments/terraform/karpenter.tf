# Karpenter v1 (current as of 1.14.x, August 2026):
#   Provisioner      -> NodePool          (karpenter.sh/v1)
#   AWSNodeTemplate  -> EC2NodeClass      (karpenter.k8s.aws/v1)
# See https://karpenter.sh/docs/upgrading/v1-migration/ and
# https://karpenter.sh/docs/concepts/nodepools/
#
# Two NodePools: `cde` (on-demand, CDE taint) and `platform` (on-demand + Spot).

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.37"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  # Pod Identity is the 2026 default; IRSA trust is also attached so the same
  # controller role works if you annotate the ServiceAccount.
  enable_pod_identity             = true
  create_pod_identity_association = true
  namespace                       = "kube-system"
  service_account                 = "karpenter"

  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = [
    "kube-system:karpenter",
  ]

  # EC2NodeClass.spec.role must match this name exactly, so no prefix.
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter_crd" {
  name                = "karpenter-crd"
  namespace           = "kube-system"
  create_namespace    = true
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter-crd"
  version             = var.karpenter_version
  wait                = true
  timeout             = 300

  depends_on = [module.eks]
}

resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = "kube-system"
  create_namespace    = true
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version
  wait                = false
  timeout             = 300
  skip_crds           = true

  values = [
    yamlencode({
      dnsPolicy = "Default"
      nodeSelector = {
        "kubernetes.io/os"        = "linux"
        "karpenter.sh/controller" = "true"
      }
      serviceAccount = {
        name = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter.iam_role_arn
        }
      }
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter.queue_name
        eksControlPlane   = true
      }
    })
  ]

  depends_on = [
    module.karpenter,
    helm_release.karpenter_crd,
  ]
}

resource "helm_release" "karpenter_nodes" {
  name      = "karpenter-nodes"
  namespace = "kube-system"
  chart     = "${path.module}/charts/karpenter-nodes"
  wait      = true
  timeout   = 120

  values = [
    yamlencode({
      clusterName  = module.eks.cluster_name
      nodeRoleName = module.karpenter.node_iam_role_name
      amiAlias     = "al2023@latest"
    })
  ]

  depends_on = [helm_release.karpenter]
}
