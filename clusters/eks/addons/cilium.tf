# Cilium as the eBPF datapath, chained with the Amazon VPC CNI so the managed
# node group can become Ready in a single terraform apply.
# Helm values match https://docs.cilium.io/en/stable/installation/k8s-install-helm/
# (EKS chaining). Chart source: https://helm.cilium.io/
resource "helm_release" "cilium" {
  name             = "cilium"
  namespace        = "kube-system"
  create_namespace = true
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = var.cilium_version
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      cluster = {
        name = var.cluster_name
      }
      k8sServiceHost = replace(var.cluster_endpoint, "https://", "")
      k8sServicePort = 443
      cni = {
        chainingMode = "aws-cni"
        exclusive    = false
      }
      enableIPv4Masquerade = false
      routingMode          = "native"
      hubble = {
        enabled = true
        relay = {
          enabled = true
        }
      }
      operator = {
        replicas = 2
      }
    })
  ]
}
