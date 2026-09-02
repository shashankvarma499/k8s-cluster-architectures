#!/usr/bin/env bash
# Delete the local kind playground cluster.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-playground}"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  printf '==> deleting kind cluster %s\n' "${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
else
  printf '==> kind cluster %s not found; nothing to delete\n' "${CLUSTER_NAME}"
fi
