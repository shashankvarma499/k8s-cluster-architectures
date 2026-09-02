#!/usr/bin/env bash
# Bring up the local kind playground: cluster, ingress-nginx, metrics-server, demo app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-playground}"
# Last ingress-nginx controller release (project retired March 2026; artifacts remain):
# https://kubernetes.github.io/ingress-nginx/deploy/
INGRESS_NGINX_CHART_VERSION="${INGRESS_NGINX_CHART_VERSION:-4.15.1}"
# metrics-server chart 3.14.0 ships app v0.9.0 (19 Aug 2026):
# https://artifacthub.io/packages/helm/metrics-server/metrics-server
METRICS_SERVER_CHART_VERSION="${METRICS_SERVER_CHART_VERSION:-3.14.0}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing prerequisite: $1"
}

need docker
need kind
need kubectl
need helm

docker info >/dev/null 2>&1 || die "Docker daemon is not running"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "kind cluster ${CLUSTER_NAME} already exists; skipping create"
else
  log "creating kind cluster ${CLUSTER_NAME}"
  kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT}/kind-config.yaml"
fi

log "exporting kubeconfig (context kind-${CLUSTER_NAME})"
kind export kubeconfig --name "${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=180s

log "installing ingress-nginx (Helm chart ${INGRESS_NGINX_CHART_VERSION})"
# Kind-specific values: hostPort + pin the controller to the extraPortMappings node.
# Equivalent static manifest:
# https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --version "${INGRESS_NGINX_CHART_VERSION}" \
  --namespace ingress-nginx \
  --create-namespace \
  --wait --timeout 5m \
  --values - <<'EOF'
controller:
  hostPort:
    enabled: true
  terminationGracePeriodSeconds: 0
  watchIngressWithoutClass: true
  extraArgs:
    publish-status-address: localhost
  nodeSelector:
    ingress-ready: "true"
    kubernetes.io/os: linux
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Equal
      effect: NoSchedule
    - key: node-role.kubernetes.io/master
      operator: Equal
      effect: NoSchedule
  service:
    type: NodePort
  admissionWebhooks:
    enabled: true
EOF

kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

log "installing metrics-server (required for HorizontalPodAutoscaler)"
helm upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server \
  --version "${METRICS_SERVER_CHART_VERSION}" \
  --namespace kube-system \
  --wait --timeout 5m \
  --values - <<'EOF'
args:
  - --kubelet-insecure-tls
EOF

log "applying example-app manifests"
kubectl apply -f "${ROOT}/example-app/namespaces"
kubectl apply -R -f "${ROOT}/example-app"
kubectl wait --namespace demo --for=condition=Available deploy --all --timeout=180s

cat <<EOF

Cluster ${CLUSTER_NAME} is ready.
  kubeconfig : ${KUBECONFIG:-${HOME}/.kube/config}
  context    : kind-${CLUSTER_NAME}

Try:
  kubectl get nodes
  kubectl get pods -n demo
  curl -sS http://localhost/
  curl -sS http://localhost/api

Tear down with: ${ROOT}/down.sh
EOF
