#!/usr/bin/env bash
# Idempotent single-node k3s install with the bundled Traefik ingress
# controller disabled. The official installer is
# https://get.k3s.io (see https://docs.k3s.io/installation/configuration).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K3S_INSTALL_URL="${K3S_INSTALL_URL:-https://get.k3s.io}"
# stable channel tracks the current GA k3s line (Kubernetes 1.35.x as of 2026-09).
INSTALL_K3S_CHANNEL="${INSTALL_K3S_CHANNEL:-stable}"
KUBECONFIG_MODE="${KUBECONFIG_MODE:-644}"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-180s}"

log() { printf '=> %s\n' "$*"; }

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd systemctl

if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    log "re-executing with sudo"
    exec sudo --preserve-env=K3S_INSTALL_URL,INSTALL_K3S_CHANNEL,KUBECONFIG_MODE,WAIT_TIMEOUT,K3S_TOKEN,INSTALL_K3S_VERSION \
      bash "$0" "$@"
  fi
  echo "error: run as root (or install sudo)" >&2
  exit 1
fi

# --disable traefik leaves Ingress objects inert until you install a
# controller yourself (see README). servicelb (Klipper) stays enabled so a
# Service of type LoadBalancer is still reachable on the node IP.
# --write-kubeconfig-mode 644 lets unprivileged users read the kubeconfig;
# equivalent env: K3S_KUBECONFIG_MODE. Docs:
# https://docs.k3s.io/cli/server and https://docs.k3s.io/installation/packaged-components
INSTALL_K3S_EXEC="${INSTALL_K3S_EXEC:-server --disable traefik --write-kubeconfig-mode ${KUBECONFIG_MODE}}"

log "installing k3s from ${K3S_INSTALL_URL} (channel=${INSTALL_K3S_CHANNEL})"
log "INSTALL_K3S_EXEC=${INSTALL_K3S_EXEC}"

curl -sfL "${K3S_INSTALL_URL}" | \
  INSTALL_K3S_CHANNEL="${INSTALL_K3S_CHANNEL}" \
  INSTALL_K3S_EXEC="${INSTALL_K3S_EXEC}" \
  sh -

# Re-running the installer is the supported way to update flags; the unit
# may need a kick if this host already had k3s.
systemctl enable --now k3s.service
systemctl is-active --quiet k3s.service

log "waiting for node to become Ready (${WAIT_TIMEOUT})"
k3s kubectl wait --for=condition=Ready node --all --timeout="${WAIT_TIMEOUT}"

if [[ -f "${SCRIPT_DIR}/manifests/hello.yaml" ]]; then
  log "applying ${SCRIPT_DIR}/manifests"
  k3s kubectl apply -f "${SCRIPT_DIR}/manifests"
fi

log "k3s is up"
k3s kubectl get nodes -o wide
k3s kubectl get pods -A
log "kubeconfig: ${K3S_KUBECONFIG}"
log "as a non-root user: export KUBECONFIG=${K3S_KUBECONFIG}"
