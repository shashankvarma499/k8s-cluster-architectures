# What's new in Kubernetes architecture

A dated, cited changelog of developments that materially change how production
Kubernetes clusters are built. Each entry points at the primary source; the
deep-dive for that layer (and, where warranted, a fintech-payments ADR) is
updated in the same commit. Entries are appended newest-first.

## 2026-09-21 — Argo CD 3.6 RC1 ships; Kubernetes 1.37.1 slips; containerd 1.7 leaves support

- **Argo CD v3.6.0-rc1** was released on 16 September 2026
  ([GitHub release](https://github.com/argoproj/argo-cd/releases/tag/v3.6.0-rc1),
  [release blog](https://blog.argoproj.io/argo-cd-v3-6-rc1-is-here-c0b562dc78d1)).
  GA remains targeted for 3 November 2026. Headline improvements: lower
  controller memory usage, a faster web UI, and better rollout visibility. The
  changelog also adds ApplicationSet **progressive-sync metrics** and condition
  reasons, built-in **health checks for Kyverno and TLSRoute**, **CloudNativePG
  hibernate/rehydrate actions**, and configurable Dex TLS minimum versions. RCs
  are test-only: keep 3.5 in production until 3.6.0 GA.
- **Kubernetes 1.37.1 has slipped** past its 2026-09-15 target date
  ([1.37 patch schedule](https://kubernetes.io/releases/1.37/)). As of
  21 September 2026, `dl.k8s.io/release/stable-1.37.txt` still resolves to
  **v1.37.0** and the
  [patch-releases page](https://kubernetes.io/releases/patch-releases/) lists
  1.37.1 as the next release. Providers that hold new minors until the first
  patch (EKS has historically followed this pattern — see the
  [1.37 breaking-changes roundup](https://shattered.io/kubernetes-1-37-release-breaking-changes-2026/))
  will keep 1.37 out of production channels until it lands.
- **containerd 1.7 reaches the end of extended support in September 2026**
  ([containerd releases page](https://containerd.io/releases/)). Committer
  support ended on 10 March 2026; the extended window through September 2026
  (maintained by two committers, focused on GKE with Kubernetes 1.30–1.32) is
  now closing. Kubernetes does not force a runtime upgrade at that date — the
  maintainers simply stop shipping patches
  ([analysis](https://dev.to/ntctech/the-kubernetes-137-deadline-that-doesnt-exist-and-the-one-that-does-1417)) —
  but plan the move to a containerd 2.x LTS line before your next node-image
  refresh.

## 2026-08-17 — Kubeflow graduates from the CNCF (backfilled 2026-09-21)

- **Kubeflow graduated from the CNCF** on 17 August 2026
  ([CNCF announcement](https://www.cncf.io/announcements/2026/08/17/cncf-announces-kubeflows-graduation-solidifying-the-standard-for-cloud-native-ai-operations/),
  [Kubeflow blog](https://blog.kubeflow.org/graduation/)). The Kubernetes-native
  ML platform reports 6,600+ contributors across 1,000+ organizations, 33,000+
  GitHub stars, ~260M PyPI downloads of its Python packages, and named adopters
  including Bloomberg, NVIDIA, Red Hat, LinkedIn, and Spotify. Graduation
  required a third-party security audit and a formalized steering committee.
  With DRA stable (1.34+) and gang scheduling beta (1.37) in core, the 2026
  "Kubernetes-native AI platform" stack now has every layer CNCF-sanctioned.
  See [ai-ml-workloads.md](ai-ml-workloads.md).
- **k8gb** — DNS-based global service load balancing for Kubernetes — **became
  a CNCF incubating project** on 5 August 2026
  ([announcement](https://www.cncf.io/announcements/2026/08/05/k8gb-becomes-a-cncf-incubating-project/)).
  Relevant to cross-region failover designs that prefer DNS over Cluster Mesh;
  see [multi-cluster-and-resilience.md](multi-cluster-and-resilience.md).

## 2026-09-14 — Karmada graduates CNCF; multi-cluster scheduling for AI goes production-grade

- **Karmada graduated from the CNCF** on 8 September 2026, announced at the
  KubeCon + CloudNativeCon + OpenInfra Summit + PyTorch Conference China 2026
  in Shanghai
  ([CNCF announcement](https://www.cncf.io/announcements/2026/09/07/cloud-native-computing-foundation-announces-karmada-graduation/)).
  Karmada extends the standard Kubernetes API with centralized placement,
  propagation, failover, and multi-cluster autoscaling; it joined as a Sandbox
  project in September 2021, moved to Incubating in December 2023, and has grown
  to 1,214+ contributors across 292 organizations. Named adopters include
  Bloomberg, Wellhub, Alibaba Cloud, Huawei, and Trip.com.
- **Karmada v1.19** advances multi-component scheduling for distributed AI
  training jobs and promotes **priority-based scheduling to Beta (enabled by
  default)** so critical workloads are placed first across the fleet. The 2026
  roadmap points at multi-cluster queuing for AI/batch and multi-cluster
  **Dynamic Resource Allocation (DRA)** across GPUs and other accelerators.
- **Why it matters:** multi-cluster workload placement is no longer a
  DIY-layer decision. Karmada now has the security audit, governance, and
  adoption signal to be a safe default for fleet scheduling — especially for
  teams stretching GPU capacity across clusters. See
  [multi-cluster-and-resilience.md](multi-cluster-and-resilience.md).

## 2026-09-14 — Upcoming releases to watch

- **Argo CD v3.6** targets RC1 on 15 September 2026 and GA on 3 November 2026
  ([release tracking issue](https://github.com/argoproj/argo-cd/issues/29396)).
  Minor-release cadence is quarterly; 3.5 remains the supported stable line until
  then.
- **Cilium 1.21** is in pre-release (`v1.21.0-pre.2`); the changelog already
  shows AWS managed prefix-list support in Cilium policies. No stable release
  yet — do not upgrade production to a pre-release.
