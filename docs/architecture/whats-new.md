# What's new in Kubernetes architecture

A dated, cited changelog of developments that materially change how production
Kubernetes clusters are built. Each entry points at the primary source; the
deep-dive for that layer (and, where warranted, a fintech-payments ADR) is
updated in the same commit. Entries are appended newest-first.

## 2026-10-05 — Kueue v0.20 GA; Kubernetes 1.38 cycle opens; Argo CD 4.0 visioning starts

- **Kueue v0.20.0** was released on 30 September 2026
  ([GitHub release](https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.0);
  v0.19.7 and v0.18.11 shipped the same day). This is a breaking release: the
  `kueue.x-k8s.io/v1beta1` API is **removed** — v1beta2 is the only served
  version, and upstream provides a
  [migration script](https://raw.githubusercontent.com/kubernetes-sigs/kueue/main/hack/migrate-to-v1beta2.sh).
  Headline changes:
  - **DRA feasibility checking** — the `KueueDRADeviceFeasibility` gate
    (Alpha, off by default) makes Kueue check per-node device availability
    before admitting a Workload that uses ResourceClaimTemplates, so quota is
    no longer reserved for Workloads the kube-scheduler cannot place.
  - **AdmissionFairSharingAnchorAtQuotaReservation** and
    **WorkloadPriorityClassDefaulting** both graduate to Beta (on by default);
    the latter auto-assigns the default WorkloadPriorityClass to workloads
    that do not specify one.
  - KubeRay v1.7 History Server options in MultiKueue; collector-sidecar
    resource accounting in Ray quotas; a LeaderWorkerSet quota-bypass fix
    behind the new `LWSImmutableGroupSize` gate (Beta); KueueViz RBAC checks
    via SubjectAccessReview.
  - See [ai-ml-workloads.md](ai-ml-workloads.md).
- **Kubernetes v1.38.0-alpha.1** was tagged on 23 September 2026 (GitHub
  release published 29 September), opening the 1.38 cycle
  ([sig-release schedule](https://git.k8s.io/sig-release/releases/release-1.38/README.md)):
  Enhancements Freeze passed on 30 September, Code/Test Freeze lands 16–17
  November, and **GA is 16 December 2026**. `dl.k8s.io/release/stable-1.37.txt`
  still resolves to v1.37.1; 1.37 remains the stable line until then.
- **Argo CD 4.0 visioning has begun.** The CNCF's ArgoCon NA preview
  (30 September 2026,
  [CNCF blog](https://www.cncf.io/blog/2026/09/30/argocon-north-america-2026-what-to-expect-as-the-argo-community-looks-toward-cd-4-0/))
  reports accelerating work across the Argo projects and the start of the
  community visioning process for Argo CD 4.0. ArgoCon NA is co-located with
  **KubeCon + CloudNativeCon NA (9–12 November 2026, Salt Lake City)**; Argo
  CD 3.6 GA remains targeted for 3 November 2026. See
  [gitops-and-delivery.md](gitops-and-delivery.md).
- **Cilium v1.21.0-pre.3** shipped 2 October 2026
  ([release](https://github.com/cilium/cilium/releases/tag/v1.21.0-pre.3)),
  adding the `lbipam.cilium.io/sharing-permit-different-pods` LB IPAM
  annotation so Services with `externalTrafficPolicy=Local` can share an IP
  when they select different Pods. Still pre-release; the stable line remains
  1.20 (v1.20.2, 16 September 2026). Do not upgrade production.
- **Karpenter v1.15** (the next quarterly minor after the v1.14 LTS) is in
  development — the AWS provider repo already documents the `spec.kubelet`
  validation changes shipping in v1.15.0
  ([PR #9656](https://github.com/aws/karpenter-provider-aws/pull/9656)).
- **Cluster API v1.14.2** (8 September 2026) is current (backfill; the docs
  previously pinned v1.14.1). The patch adds a `--tls-curve-preferences`
  manager flag plus KCP/ClusterClass fixes
  ([release](https://github.com/kubernetes-sigs/cluster-api/releases/tag/v1.14.2)).

## 2026-09-28 — Kubernetes 1.37.1 ships; Velero's CNCF move (backfill); Kueue v0.20 RC

- **Kubernetes v1.37.1** was released on 23 September 2026
  ([GitHub release](https://github.com/kubernetes/kubernetes/releases/tag/v1.37.1),
  [patch-releases page](https://kubernetes.io/releases/patch-releases/)),
  alongside **v1.36.5, v1.35.9, and v1.34.12** for the older supported
  branches. `dl.k8s.io/release/stable-1.37.txt` now resolves to v1.37.1.
  Notable fix: a **v1.34+ regression** handling containers whose environment
  values come from Secret objects containing binary non-UTF-8 data
  ([changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.37.md)).
  The first patch is the gate several managed offerings wait for before
  enabling a new minor (EKS historically ships a minor only after its first
  patch), so expect 1.37 rollout on managed services to accelerate.
- **Velero joined the CNCF as a Sandbox project** (backfill): the CNCF TOC
  accepted the application and the move was announced at KubeCon +
  CloudNativeCon Europe 2026 in Amsterdam
  ([Velero blog](https://velero.io/blog/velero-joins-cncf-sandbox/),
  [CNCF news](https://www.cncf.io/news/2026/04/02/the-new-stack-why-broadcom-gave-velero-to-the-cncf-sandbox-and-what-it-means-for-kubernetes-data-protection/)).
  Broadcom (which inherited Velero via the VMware acquisition of Heptio)
  donated the project; the repository moved from `vmware-tanzu/velero` to the
  neutral [`velero-io` GitHub organization](https://github.com/velero-io/velero),
  and maintainers now include Broadcom, Red Hat, and Microsoft. Velero reports
  10,000+ GitHub stars and 500M+ Docker Hub pulls. Single-vendor governance
  risk is now off the table for the de-facto default Kubernetes backup tool —
  see [multi-cluster-and-resilience.md](multi-cluster-and-resilience.md).
  Current line: **v1.18.4** (2026-09-28; v1.18.3 on 2026-09-21).
- **Kueue v0.20.0-rc.1** was published on 24 September 2026
  ([GitHub release](https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.0-rc.1)).
  GA of the v0.20 line is imminent; v0.19.x remains the stable line until then.

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
