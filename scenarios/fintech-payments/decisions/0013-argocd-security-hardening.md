# 0013. Emergency Argo CD hardening after the October 2026 advisory batch

- Status: Accepted
- Date: 2026-10-12

## Context

On 6 October 2026 the Argo project disclosed eight security advisories, four
CRITICAL, affecting all supported lines:

- A Kustomize **remote ref** can run commands in the repo-server
  ([GHSA-9v9p-x54c-58gc](https://github.com/argoproj/argo-cd/security/advisories/GHSA-9v9p-x54c-58gc)).
- A Kustomize **Helm config home** can run commands in the repo-server
  ([GHSA-fw5c-w8rc-j7fx](https://github.com/argoproj/argo-cd/security/advisories/GHSA-fw5c-w8rc-j7fx)).
- A **Jsonnet import can read files** from the repo-server
  ([GHSA-m3vr-7329-44ww](https://github.com/argoproj/argo-cd/security/advisories/GHSA-m3vr-7329-44ww)).
- **AppProject restrictions are bypassed** by PreDelete/PostDelete resource
  hooks ([GHSA-fmxq-cgp8-87wp](https://github.com/argoproj/argo-cd/security/advisories/GHSA-fmxq-cgp8-87wp),
  CVE-2026-77459).
- HIGH: login rate-limit bypass (CVE-2025-61560); SSH proxy-URL command
  injection (CVE-2026-55797); MODERATE: extension-proxy RBAC namespace
  handling; OCI manifest memory exhaustion.

Fixes shipped in **v3.6.0-rc2** and were backported to **3.5.4 / 3.4.10 /
3.3.15**; bugfix patches 3.5.5 / 3.4.11 / 3.3.16 followed on 12 October 2026
([3.6.0-rc2 release notes](https://github.com/argoproj/argo-cd/releases/tag/v3.6.0-rc2)).

[ADR 0004](0004-argocd-gitops-app-of-apps.md) pins this platform to Argo CD
**3.5.2**, which is vulnerable. The repo-server holds credentials for every
application repository, so four CRITICAL paths through it (including two
command-execution paths reachable from Git content) are an immediate,
in-scope risk for the PCI CDE: an attacker with push access to any configured
repo (or a malicious Kustomize remote base) could execute commands in
`argocd`.

## Decision

- **Patch immediately and pin above the vulnerable range.** Bump the platform
  to Argo CD **3.5.5** (chart `argo/argo-cd` 10.6.4 with
  `global.image.tag=v3.5.5`), and treat 3.5.4+ / 3.4.10+ / 3.3.15+ as the
  minimum acceptable versions on every cluster. This supersedes the 3.5.2
  pin in ADR 0004.
- **No Kustomize remote bases.** Applications must not use remote
  `resources:`/`components:` refs in `kustomization.yaml`. The CDE app
  templates are self-contained; add a Kyverno policy in the `platform`
  project that blocks syncs whose manifests declare remote refs.
- **No Helm plugins in the repo-server.** Kustomize-rendered Helm charts
  must not depend on `helmGlobals.configHome` plugins (the fix no longer
  honors that directory — a potentially breaking change we accept, since no
  CDE chart uses a plugin).
- **Keep the OCI manifest cap.** Do not raise the new 4 MiB manifest limit;
  image repos stay well under it.
- **No resource hooks in AppProject-managed namespaces.** The platform does
  not use PreDelete/PostDelete hooks. Extend the existing Gatekeeper
  policies to deny the `argocd.argoproj.io/hook` annotation outside the
  `argocd` namespace so the bypass class (CVE-2026-77459) cannot recur.
- **Emergency patch window.** CRITICAL GitOps security patches may be
  applied out-of-band of the normal change window under PCI 4.0 Req. 6.3.4
  (emergency changes): deploy the patch, then backfill the change record.
- **Track 3.6 only after GA.** Adoption of 3.6 (GA targeted 3 November 2026)
  follows the normal minor-upgrade path after its first patch, per the
  existing release policy.

## Consequences

- The two hardening changes (no `helmGlobals.configHome` for Kustomize+Helm
  builds; 4 MiB OCI cap) are verified in staging before production — the
  platform's charts do not use either feature, so impact is expected to be
  nil, but the check is mandatory.
- A Kyverno/Gatekeeper rule touching GitOps syncs adds a small policy
  surface; it is applied in the `platform` project so it cannot be edited by
  CDE tenants.
- Emergency-patch procedures are now exercised and documented; the runbook
  gains an "Argo CD CVE" section.
- Being pinned to 3.5.5 keeps the platform one minor behind the 3.6 feature
  line for a few weeks; acceptable trade-off for a security-blessed patch
  line.

## Alternatives considered

- **Stay on 3.5.2.** Rejected: four CRITICALs in the CDE delivery path
  cannot be accepted as residual risk.
- **Jump to 3.6.0-rc2.** Rejected: RCs are not supported for production
  upgrades; the fixes are already backported to the 3.5 patch line we run.
- **Migrate to Flux 2.9.** Rejected for the same reasons as ADR 0004
  (Rollouts, UI, team skill set); Flux does not share these advisory paths
  but a migration during an emergency is worse than a patch.
- **Ignore the potentially-breaking hardening changes via config.**
  Rejected: re-enabling `configHome` or raising the OCI cap would restore
  the attack surface the advisories closed.
