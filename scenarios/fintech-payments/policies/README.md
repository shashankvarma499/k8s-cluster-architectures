# Gatekeeper policies

OPA Gatekeeper ConstraintTemplates (`templates.gatekeeper.sh/v1`) and Constraints (`constraints.gatekeeper.sh/v1beta1`) for the CDE. Sourced from the [Gatekeeper library](https://open-policy-agent.github.io/gatekeeper-library/) where a library template exists; `K8sGatewayHttpsOnly` is local.

Install Gatekeeper first (Argo CD Application `platform-gatekeeper` sync-wave `-3`), then this chart.

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm upgrade --install gatekeeper gatekeeper/gatekeeper --namespace gatekeeper-system --create-namespace
helm template gatekeeper-policies charts/gatekeeper-policies | kubectl apply -f -
```

| Constraint | What it enforces | Library |
| --- | --- | --- |
| `K8sRequiredResources` | CPU+memory **requests and limits** | local (same idea as [containerlimits](https://open-policy-agent.github.io/gatekeeper-library/website/validation/containerlimits) + required resources) |
| `K8sPSPMustRunAsNonRoot` | `runAsNonRoot: true` or `runAsUser != 0` | simplified [allowed users](https://open-policy-agent.github.io/gatekeeper-library/) |
| `K8sPSPPrivilegedContainer` | no `privileged: true` | [privileged-containers](https://open-policy-agent.github.io/gatekeeper-library/website/validation/privileged-containers) |
| `K8sHttpsOnly` | Ingress has TLS + `kubernetes.io/ingress.allow-http=false` | [httpsonly](https://open-policy-agent.github.io/gatekeeper-library/website/validation/httpsonly) |
| `K8sGatewayHttpsOnly` | Gateway listeners are HTTPS or TLS | local |

`kube-system`, `gatekeeper-system`, and `argocd` are excluded. PSA Restricted is still labeled on application namespaces ([ADR 0009](../decisions/0009-gatekeeper-and-psa.md)).
