# 0004. Argo CD 3.5 app-of-apps as the delivery control plane

- Status: Accepted
- Date: 2026-09-02

## Context

A payments cluster that is configured by `kubectl apply` from laptops cannot pass PCI Req. 6 (change control) or Req. 7 (least privilege). GitOps makes Git the desired state and the Git history the change ticket. The two CNCF-graduated reconcilers in 2026 are [Argo CD 3.5.2](https://github.com/argoproj/argo-cd/releases/tag/v3.5.2) (26 August 2026) and [Flux 2.9](https://fluxcd.io/). Progressive delivery on the Argo side is Rollouts ([ADR 0005](0005-argo-rollouts-progressive-delivery.md)).

App-of-apps: one root `Application` (`argoproj.io/v1alpha1`) whose source is a directory of child `Application` objects, one per service ([Argo CD declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)).

## Decision

- Install Argo CD **3.5.2** via Helm chart **10.6.4** (`https://argoproj.github.io/argo-helm`) in HA mode, namespace `argocd`.
- Bootstrap with [`gitops/charts/bootstrap`](../gitops/charts/bootstrap): a single root Application pointing at this repo.
- Child Applications live in [`gitops/charts/app-of-apps`](../gitops/charts/app-of-apps), one per service (gateway, api, ledger, fraud, webhooks) plus platform (observability, vault, velero, gatekeeper, tetragon, rollouts).
- AppProject `cde` may destinate only `cde-*` namespaces. AppProject `platform` destines the rest. SSO + MFA on the Argo CD UI (PCI 4.0.1 MFA for CDE access).
- Enable commit-signature verification / source integrity introduced in 3.5 ([InfoQ summary](https://www.infoq.com/news/2026/06/argocd-supply-chain-security/)).

## Consequences

- Every CDE change is a Git commit. Break-glass `kubectl` is an incident.
- Argo CD is **connected-to** the CDE (it can ship code that reads tokens). It is in the ROC. RBAC and AppProjects are in-scope controls.
- App-of-apps is explicit YAML. When the fleet grows past ~20 apps, ApplicationSets become the follow-up ADR.
- Helm 4 support in Argo CD 3.5 is available; our charts are Helm 3 `apiVersion: v2` and remain compatible.

## Alternatives considered

- **Flux 2.9.** Better multi-tenant controller split, native OCI, no fat repo-server. Rejected because Rollouts + the Argo UI are the org’s existing skill set; Flux would add Flagger.
- **ApplicationSet from day one.** Fewer files, more indirection. Rejected until the service list is boring.
- **Terraform helm_release for every app.** Terraform state as a CD system. Slow, poor drift UX, mixes infra and apps.
- **Jenkins/`kubectl apply`.** No continuous reconciliation; drift is invisible.
