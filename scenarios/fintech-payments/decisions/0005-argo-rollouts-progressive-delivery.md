# 0005. Argo Rollouts for the authorization path

- Status: Accepted
- Date: 2026-09-02

## Context

A 100% Deployment rollout of `payments-api` that 5xxs is a revenue incident. Kubernetes Deployments support rolling updates, not metric-gated canaries. [Argo Rollouts](https://argo-rollouts.readthedocs.io/) v1.9.1 (6 July 2026, [release](https://github.com/argoproj/argo-rollouts/releases/tag/v1.9.1); Helm chart 2.41.1) adds canary/blue-green, weighted traffic, and `AnalysisTemplate` against Prometheus. Gateway API HTTPRoute weights are the 2026 traffic backend; ingress-nginx annotations are unpatched ([retirement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)).

## Decision

- Replace `Deployment` with `Rollout` (`argoproj.io/v1alpha1`) for `payments-api` and `payments-gateway`.
- Canary steps: 10% → pause 5m → 50% → pause 10m → 100%, `maxUnavailable: 0`.
- `AnalysisTemplate` queries kube-prometheus-stack for 5xx ratio; `successCondition: result[0] >= 0.99`, `failureLimit: 3`. Failed analysis **aborts**.
- `fraud-engine` and `webhook-dispatcher` stay on Deployment + standard rolling update (lower blast radius).
- Traffic shaping via Gateway API when the controller supports weight; until then, replica-weighted canary (Rollouts default) is acceptable because both versions share the Service.

## Consequences

- Bad builds stop at 10% of authorization traffic, not 100%.
- Rollouts CRDs must be installed before the app-of-apps syncs CDE apps (sync-wave `-1` on the rollouts Application).
- Analysis depends on Prometheus being up. If Prometheus is down, canaries pause — fail-closed, which is what we want on the auth path.
- Engineers need `kubectl argo rollouts` (or the dashboard, NetworkPolicy-restricted) to unpause.

## Alternatives considered

- **Deployment rollingUpdate.** Simple. No SLO gate. Rejected for CDE.
- **Flagger.** Flux-native. We are not on Flux ([ADR 0004](0004-argocd-gitops-app-of-apps.md)).
- **Blue/green.** Cleaner rollback, 2× capacity during the cut. Rejected as the default because Black Friday capacity is already expensive; keep blue/green as an option for ledger schema migrations.
- **Service mesh traffic split (Istio/Linkerd).** Extra datapath in the CDE. Not until we adopt ambient for other reasons.
