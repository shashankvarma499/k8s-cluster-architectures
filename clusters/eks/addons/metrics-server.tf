# metrics-server (HPA / kubectl top). Chart:
# https://kubernetes-sigs.github.io/metrics-server/
# On EKS the kubelet serving cert is valid, so --kubelet-insecure-tls is NOT set.
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = "kube-system"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      replicas = 2
      args = [
        "--kubelet-preferred-address-types=InternalIP",
      ]
      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }
    })
  ]
}
