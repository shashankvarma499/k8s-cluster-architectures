# What's new in Kubernetes architecture

A dated, cited changelog of developments that materially change how production
Kubernetes clusters are built. Each entry points at the primary source; the
deep-dive for that layer (and, where warranted, a fintech-payments ADR) is
updated in the same commit. Entries are appended newest-first.

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
