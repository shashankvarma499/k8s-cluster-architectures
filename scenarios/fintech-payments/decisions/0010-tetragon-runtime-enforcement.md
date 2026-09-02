# 0010. Tetragon for eBPF runtime enforcement

- Status: Accepted
- Date: 2026-09-02

## Context

Admission decides what may start. It cannot see a reverse shell that a vulnerable library execs at 02:00. [Tetragon](https://tetragon.io/) (Cilium project) attaches eBPF to kprobes, LSM, and (v1.7) fentry/fexit, understands Kubernetes identities, and can **Sigkill in-kernel** without a userspace round trip. [v1.7.1](https://github.com/cilium/tetragon/releases/tag/v1.7.1) (25 August 2026) is current; Helm chart 1.7.0 is on [helm.cilium.io](https://helm.cilium.io/). Falco is the detection-oriented alternative.

PCI-DSS 4.0.1 Req. 5 (malware) and Req. 10 (monitor) need runtime evidence that CDE processes did not spawn shells or open unexpected networks.

## Decision

- Install Tetragon as a DaemonSet in `kube-system` via Helm chart 1.7.0, image `quay.io/cilium/tetragon:v1.7.1`.
- Apply a `TracingPolicy` (namespaced) in each CDE namespace:
  - `Sigkill` on exec of `/bin/sh`, `/bin/bash`, `/usr/bin/apk`, `/usr/bin/apt` in payments containers.
  - Observe (not kill) `connect` to destinations outside the allowlisted cluster CIDR + Vault + Gateway.
- Export JSON to the OpenTelemetry Collector → Loki. Alerts in Prometheus on `tetragon_events_total{action="Sigkill"}`.
- Falco is not installed.

## Consequences

- A legitimate debug `kubectl exec -- /bin/sh` into a CDE pod is killed. That is the point. Debugging uses ephemeral debug containers in a break-glass namespace, or a rebuild.
- Tetragon is privileged (it must). PSA exempts `kube-system`. The DaemonSet is in-scope for PCI.
- False positives on distroless vs alpine: pin images so the policy matches real binaries.
- v1.7.1 removed `returnArgAction: Post`; policies must not use it ([upgrade notes](https://github.com/cilium/tetragon/releases/tag/v1.7.1)).

## Alternatives considered

- **Falco.** Huge rules library, userspace decisions, TOCTOU window. Better as a detection feed; we need enforcement.
- **seccomp/AppArmor only.** Necessary (PSA Restricted already sets RuntimeDefault) but coarse; no Kubernetes-identity-aware “this ns cannot exec bash.”
- **No runtime agent.** Cheaper. Blind. Rejected for CDE.
- **Cilium L7 NetworkPolicy as the only runtime control.** Covers packets, not exec.
