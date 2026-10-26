# What's new in Kubernetes architecture

A dated, cited changelog of developments that materially change how production
Kubernetes clusters are built. Each entry points at the primary source; the
deep-dive for that layer (and, where warranted, a fintech-payments ADR) is
updated in the same commit. Entries are appended newest-first.

## 2026-10-26 — eMudhra CA compromise hits the Go trust store (CVE-2026-111943); Cilium & Istio ship out-of-band patches

- **CVE-2026-111943: compromised eMudhra intermediate CA keys.** Go
  **1.27.3 / 1.26.10** (19 October 2026) hard-block the SPKI hashes of
  **eight compromised eMudhra intermediate CA keys** in `crypto/x509`, so
  no certificate chain under them verifies anymore
  ([Go issue #82345](https://github.com/golang/go/issues/82345),
  [Talos](https://blog.talosintelligence.com/compromised-intermediate-certificates/),
  [Threat Landscape analysis](https://threatlandscape.io/blog/go-hard-blocks-emudhra-intermediate-ca-keys-cve-2026-111943)).
  - The Go advisory does not name the CA; independent analysis ties the
    eight keys to intermediates under the **emSign Root TLS CA - G3** and
    **emSign Root CS CA - G3** hierarchies. The companion
    **CVE-2026-111944** covers the non-Go trust stacks
    ([Qualys](https://blog.qualys.com/product-tech/2026/10/23/how-to-identify-compromised-emudhra-certificates-with-qualys-cve-2026-111943-and-cve-2026-111944/)).
  - The operational trap: **upgrading the Go toolchain patches nothing by
    itself.** Every Go-built image in the cluster — controllers,
    webhooks, CNI, operators — must be *rebuilt* with Go ≥ 1.27.3 /
    1.26.10 (or patched by its vendor) before it stops trusting the
    compromised intermediates. Treat this as a fleet-wide image-rebuild
    event, not a package update. See [security.md](security.md).
- **Cilium v1.20.4 / v1.19.10 / v1.18.16** (23 October) — out-of-band
  security patch: Go 1.26.10, deps refreshed
  ([release](https://github.com/cilium/cilium/releases/tag/v1.20.4)).
  Also fixes a **v1.20.3 regression** where Gateway API `BackendTLSPolicy`
  handling caused high CPU and traffic-forwarding failure, plus the usual
  bugfix batch. See [networking.md](networking.md).
- **Istio 1.31.3 / 1.30.7** (21 October,
  [announcement](https://istio.io/latest/news/releases/1.31.x/announcing-1.31.3/),
  [ISTIO-SECURITY-2026-008](https://istio.io/latest/news/security/istio-security-2026-008/)):
  Go 1.26.10 in istiod/istioctl/pilot-agent and rustls-webpki 0.103.16 in
  ztunnel reject the compromised chains, and **emSign ECC Root CA - G3**
  is dropped from the ubuntu-based and distroless image CA bundles. Also:
  the ambient node-untaint controller can now wait for **ztunnel
  readiness** (`PILOT_NODE_UNTAINT_CHECK_ZTUNNEL=true`, off by default),
  and istiod auto-renews an expired self-signed CA in `istio-ca-secret`
  instead of failing to start. That is **three Istio security batches in
  five weeks** — budget for monthly mesh patching, ambient included.
  **Istio 1.32.0-beta.0** (22 October) opened the next dev cycle.
- **Kubernetes 1.34 reaches end of life on 27 October 2026** — this week
  (flagged last run). v1.34.12 (15 September) was its final patch;
  clusters still on 1.34 stop receiving CVE fixes immediately
  ([patch-releases page](https://kubernetes.io/releases/patch-releases/)).
- **The Kubernetes October patch round still has not landed.** As of
  26 October, `dl.k8s.io/release/stable-1.37.txt` still resolves to
  **v1.37.1** (next: 1.37.2) and stable-1.36 to v1.36.5 (next: 1.36.6) —
  the mid-October round is now ~two weeks late. The 1.38 cycle is
  unchanged at alpha.2; Code/Test Freeze lands 16–17 November and GA on
  16 December ([schedule](https://www.kubernetes.dev/resources/release/)).
- **Argo CD v3.6.0-rc4** (22 October) — bug fixes (sharding recompute
  when an unknown cluster appears, SSH fetch through SOCKS5 proxies,
  server-side diff false positives), Go 1.27.3; GA target remains
  3 November
  ([release](https://github.com/argoproj/argo-cd/releases/tag/v3.6.0-rc4)).
  Bugfix patches **v3.5.6** (20 October) and **v3.3.18** (22 October) are
  current on the older lines.
- **Gateway API v1.7.0-rc.3** (23 October,
  [release](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.7.0-rc.3)):
  **rc.2 was retired** after a problem with its release manifests;
  pre-routing listener filters can now attach via **ListenerSet**
  (GEP-5224); `HTTPRouteRetry.Attempts` reverted to `*int` with minimum 0
  so retries can be disabled per rule; **TLSRouteMixedMode** moved to the
  Standard channel.
- **Karpenter v1.15.1 + v1.14.3** (23 October) — patch releases on both
  current lines
  ([release](https://github.com/kubernetes-sigs/karpenter/releases/tag/v1.15.1)).
- **Kueue v0.20.3 / v0.19.10** (22 October,
  [release](https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.3)):
  MultiKueue **RayService in-tree autoscaling** on worker clusters
  (feature gate), a classical-preemption candidate-order cache (alpha),
  and a DRA quota-charging fix for DeviceClasses requested by implicit
  extended-resource name.
- **vCluster v0.37.4** (20 October) — patch on the stable line; the
  v0.38 alpha series is in flight
  ([release](https://github.com/loft-sh/vcluster/releases/tag/v0.37.4)).
- **Unchanged:** Velero v1.18.4, Tetragon v1.7.1, Cluster API v1.14.3,
  KubeVirt v1.10.0-beta.0. No CNCF graduations and no notable production
  post-mortems surfaced this week. KubeCon + CloudNativeCon NA opens
  9–12 November in Salt Lake City — expect the next announcement wave
  there.

## 2026-10-19 — Istio 1.31.2 security batch (ISTIO-SECURITY-2026-007); two backfilled Kubernetes CVEs; 1.34 EOL on 27 October

- **Istio 1.31.2 / 1.30.6 / 1.29.9** shipped on 15–16 October 2026 as
  security release **ISTIO-SECURITY-2026-007**
  ([1.31.2 announcement](https://istio.io/latest/news/releases/1.31.x/announcing-1.31.2/),
  [advisory](https://istio.io/latest/news/security/istio-security-2026-007/)):
  - Two Envoy CVEs: **GHSA-8vc2-jrm4-835w** (CVSS 7.5) and
    **GHSA-47vj-9r25-wv5j** (CVSS 6.5) — unauthenticated crashes of the
    OAuth2 and api_key_auth HTTP filters on CONNECT requests without a
    `:path` header.
  - Two Istio CVEs: **GHSA-w44g-8m76-8gc5** (CVSS 7.4) —
    AuthorizationPolicy method rules bypassed over HTTP/2 by changing
    the case of the method — and **GHSA-7p2q-4xvg-vxc6** (CVSS 7.7) —
    istiod crashes in **ambient mode** when a ServiceEntry claims the
    address of an IP-addressed waypoint.
  - Hardening: `istioctl` now verifies the istiod certificate when
    talking to XDS (`--insecure` to skip); `istioctl manifest translate`
    escapes values to close a shell-injection hole; the Wasm OCI
    fetcher's plaintext-HTTP retry is now allowlist-only
    (`WASM_INSECURE_REGISTRIES`); a new `MAX_RA_WORKLOAD_CERT_TTL`
    (default 48h) caps certificate TTL on the experimental Kubernetes
    CSR RA path.
  - This is the second security batch in four weeks (006 landed
    21 September): treat Istio as a monthly-patch dependency — ambient
    included. See [networking.md](networking.md).
- **Backfill — Kubernetes disclosed two Medium CVEs**, both fixed in the
  23 September patch round (v1.37.1 / 1.36.5 / 1.35.9 / 1.34.12) that
  this changelog covered on 28 September without the CVE details:
  - **CVE-2026-2270** (CVSS 5.9, disclosed 23 September): a confused
    deputy in the StatefulSet controller lets a user with
    namespace-scoped write on StatefulSet *and* ControllerRevision
    objects create a **cross-namespace Pod** with full control over its
    spec and metadata. Fixed by restoring only `spec` from
    ControllerRevisions. Directly relevant to multi-tenant clusters
    ([advisory](https://discuss.kubernetes.io/t/security-advisory-cve-2026-2270-statefulset-and-controllerrevision-write-permissions-allow-cross-namespace-pod-creation/35276),
    [issue #142097](https://github.com/kubernetes/kubernetes/issues/142097)).
  - **CVE-2026-19444** (CVSS 6.5, disclosed 28 September): `kubectl cp`
    path traversal on **Windows clients** — a malicious tar binary in a
    container can write files to arbitrary paths on the local machine,
    limited by the local user's permissions. Linux/macOS clients are
    unaffected; remediation is a client upgrade to kubectl ≥ v1.34.12 /
    1.35.9 / 1.36.5
    ([advisory](https://discuss.kubernetes.io/t/security-advisory-cve-2026-19444-kubectl-cp-path-traversal-on-windows-allows-arbitrary-file-writes/35301),
    [issue #141294](https://github.com/kubernetes/kubernetes/issues/141294)).
    See [security.md](security.md).
- **Kubernetes 1.34 reaches end of life on 27 October 2026**
  ([patch-releases page](https://kubernetes.io/releases/patch-releases/)).
  1.34 entered maintenance mode on 27 August; v1.34.12 (15 September)
  was its final patch. Clusters still on 1.34 stop receiving CVE fixes
  next week — finish the move to 1.35/1.36/1.37 now.
- **The October patch round has not landed yet.** As of 19 October,
  `dl.k8s.io/release/stable-1.37.txt` still resolves to **v1.37.1** and
  `latest.txt` to v1.38.0-alpha.2; the expected 1.37.2 / 1.36.6 /
  1.35.10 round slips past the mid-October estimate
  ([stable-1.37.txt](https://dl.k8s.io/release/stable-1.37.txt)).
- **Argo CD v3.6.0-rc3** published 15 October
  ([release](https://github.com/argoproj/argo-cd/releases/tag/v3.6.0-rc3)):
  mostly bug fixes (reposerver CMP goroutine/stale-manifest leak, OCI
  tag-list caching, escaped repo-creds URL routing) plus configurable
  **Dex TLS cipher suites and curve preferences**. GA target remains
  3 November 2026; keep 3.5.5 in production until then.
- **Cilium v1.20.3** (+ v1.19.9, v1.18.15) shipped 15 October
  ([release](https://github.com/cilium/cilium/releases/tag/v1.20.3)):
  regular patch, no CVEs. Notable fixes: a conntrack GC race that could
  delete a live connection's NAT mapping and reallocate its SNAT source
  port, and the operator now **errors on CiliumNetworkPolicies with
  `nodeSelector`** instead of silently enforcing nothing. Cilium 1.21
  remains pre-release (v1.21.0-pre.3).
- **Kueue v0.20.2 and v0.19.9** published 15 October
  ([release](https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.2)):
  bug fixes including a DRA admission charge recompute when a Workload
  is updated mid-scheduling, FairSharing preemption fixes, and kueuectl
  CLI corrections.
- **Karpenter v1.14.2** published 16 October — a patch on the v1.14 LTS
  line
  ([release](https://github.com/kubernetes-sigs/karpenter/releases/tag/v1.14.2));
  v1.15.0 remains the current line.
- **KubeVirt v1.10.0-beta.0** published 13 October
  ([release](https://github.com/kubevirt/kubevirt/releases/tag/v1.10.0-beta.0)):
  beta with breaking changes — the launcher-plugin `spec.domainHooks` is
  renamed `spec.launcherHooks` (explicit hook points; `PreVMStop` →
  `OnVMStop`), virt-launcher-monitor no longer handles Istio sidecar
  termination (**Istio ≥ 1.27 required**, or native sidecar mode), and
  virt-export Services move to headless on 8443. Do not run in
  production.
- **Cluster API v1.14.3** (7 October, backfill)
  ([release](https://github.com/kubernetes-sigs/cluster-api/releases/tag/v1.14.3)):
  bug-fix patch (KCP etcd-member matching, owner-reference resolution);
  support matrix unchanged — management clusters v1.33–v1.37, workload
  clusters v1.31–v1.37. grpc bumped to 1.83.2 for security advisories.
- **Unchanged since last run:** Gateway API v1.7.0-rc.1 (8 October) is
  still the newest tag — no v1.7 GA yet; Velero v1.18.4 and Tetragon
  v1.7.1 remain current; no new CNCF graduations; no notable production
  post-mortems surfaced this week. KubeCon + CloudNativeCon NA is
  9–12 November in Salt Lake City — expect the next major announcement
  wave there.

## 2026-10-12 — Argo CD security advisory batch (4 CRITICAL); Karpenter v1.15 GA; Gateway API v1.7 RC1

- **Argo CD disclosed eight security advisories on 6 October 2026**, four
  CRITICAL, fixed in **v3.6.0-rc2, v3.5.4, v3.4.10, and v3.3.15**
  ([3.6.0-rc2 release notes](https://github.com/argoproj/argo-cd/releases/tag/v3.6.0-rc2)):
  - CRITICAL: a Kustomize **remote ref** can run commands in the repo-server
    ([GHSA-9v9p-x54c-58gc](https://github.com/argoproj/argo-cd/security/advisories/GHSA-9v9p-x54c-58gc));
    a Kustomize **Helm config home** can run commands in the repo-server
    ([GHSA-fw5c-w8rc-j7fx](https://github.com/argoproj/argo-cd/security/advisories/GHSA-fw5c-w8rc-j7fx));
    a **Jsonnet import can read files** from the repo-server
    ([GHSA-m3vr-7329-44ww](https://github.com/argoproj/argo-cd/security/advisories/GHSA-m3vr-7329-44ww));
    **AppProject restrictions are bypassed** by PreDelete/PostDelete resource
    hooks ([GHSA-fmxq-cgp8-87wp](https://github.com/argoproj/argo-cd/security/advisories/GHSA-fmxq-cgp8-87wp),
    **CVE-2026-77459**).
  - HIGH: login failure rate limit bypassable via concurrent requests
    ([GHSA-4439-h7jw-5cjj](https://github.com/argoproj/argo-cd/security/advisories/GHSA-4439-h7jw-5cjj),
    CVE-2025-61560); command injection via a repository proxy URL on SSH Git
    remotes ([GHSA-j6cw-g6p4-7hch](https://github.com/argoproj/argo-cd/security/advisories/GHSA-j6cw-g6p4-7hch),
    CVE-2026-55797). Two MODERATE: extension-proxy RBAC ignores the
    application namespace with `applications-in-any-namespace` enabled, and
    an oversized OCI manifest can exhaust repo-server memory.
  - Two **potentially-breaking hardening changes** ship with the fixes:
    Kustomize builds that render Helm charts no longer honor
    `helmGlobals.configHome` (Helm plugins registered there stop loading),
    and OCI manifests larger than **4 MiB are rejected**.
  - Production guidance: upgrade to **3.5.4 / 3.4.10 / 3.3.15 or newer**
    immediately; bugfix patches v3.5.5 / v3.4.11 / v3.3.16 followed on
    12 October 2026. See [gitops-and-delivery.md](gitops-and-delivery.md)
    and
    [ADR 0013](../scenarios/fintech-payments/decisions/0013-argocd-security-hardening.md).
- **Karpenter v1.15.0 GA'd on 10 October 2026**, one quarter after the v1.14
  LTS line ([release](https://github.com/kubernetes-sigs/karpenter/releases/tag/v1.15.0);
  [AWS provider v1.15.0](https://github.com/aws/karpenter-provider-aws/releases/tag/v1.15.0)
  the same day). Headlines: **DRA prioritized alternatives** support; a new
  **VPA prediction controller and store** (Karpenter's first step toward
  predictive node scaling); default **pod topology spread awareness** when
  bin-packing; accounting for **instance-type volume limits** at
  provisioning time; node repair reclassified as **voluntary disruption**
  with terminate-first drift for capacity-constrained NodePools; **reboot**
  as a node action; a feature-gated pod deletion-cost controller; and new
  disruption metrics (`karpenter_pods_disrupted_total`, `consolidation_policy`
  and `termination_mode` labels). The upgrade guide graduates the **Capacity
  Buffers API to v1beta1** (new `autoscaling.x-k8s.io` CRD — upgrade the
  standalone `karpenter-crd` chart alongside the controller). See
  [control-plane-and-node-lifecycle.md](control-plane-and-node-lifecycle.md).
- **Gateway API v1.7.0-rc.1 shipped on 8 October 2026**
  ([release](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.7.0-rc.1),
  alongside the v1.6.3 patch). **HTTPRoute Retries (GEP-1731)** — `codes`,
  `attempts`, `backoff` — graduates to the **Standard channel**. New in
  Experimental: per-address **Gateway Address Routability** (GEP-5093), a
  **standardized attribute dictionary** based on OpenTelemetry semantics
  (GEP-5253), session persistence moved to **XBackend** (GEP-1619/4894),
  **pre-routing listener filters** (GEP-5224), **ClusterTrustBundle** support
  in `caCertificateRefs` (GEP-5075), and the `XTelemetryPolicy`
  distributed-tracing API (GEP-4768). See [networking.md](networking.md).
- **Kubernetes v1.38.0-alpha.2** was published on 7 October 2026
  ([release](https://github.com/kubernetes/kubernetes/releases/tag/v1.38.0-alpha.2));
  `latest.txt` now resolves to it while `stable-1.37.txt` remains v1.37.1
  (no new patch this week). The 1.38 cycle's headline security work is the
  start of the **post-quantum migration**: ML-DSA (FIPS 204) support across
  the control plane — **Beta** pod-certificate signing via
  `PodCertificateRequest` and projected volumes, PKCS#10 CSR signing behind
  the `CertificateSigningRequestMLDSA` feature gate, kubelet client/server
  key-algorithm selection (ECDSA/RSA/ML-DSA), client-go ML-DSA keys via Go
  1.27 `crypto/mldsa`, and kubeadm `ML-DSA-44/65/87` encryption algorithms
  ([1.38 changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.38.md)).
  See [security.md](security.md).
- **Kueue v0.20.1 and v0.19.8** patches shipped on 8 October 2026
  ([release](https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.1)),
  the first patches after the breaking v0.20.0.
- **KubeVirt v1.9.1** was tagged on 12 October 2026 — 83 changes including
  libvirt 11.10.0, Windows crash-dump handling, and Vera Rubin GPU
  passthrough recognition
  ([release](https://github.com/kubevirt/kubevirt/releases/tag/v1.9.1)).
  GitHub flags it pre-release at time of writing — verify before upgrading.
- **Backfill — Istio 1.31.1** (21 September 2026) is a security release
  fixing **ISTIO-SECURITY-2026-006**: 13 CVEs — Envoy heap use-after-free on
  HTTP/2 trailers, a `safe_regex` negative-match **fail-open** in RBAC, a
  QUIC HTTP/3 use-after-free, plus Istio fixes for an EnvoyFilter
  control-plane DoS and a **BackendTLSPolicy fail-open on sidecars** (CVSS
  7.7) ([advisory](https://istio.io/latest/news/security/istio-security-2026-006/)).
  Patches: 1.31.1, 1.30.5, 1.29.8. The 1.32 dev cycle opened with
  `1.32.0-alpha.0` on 5 October 2026. See [networking.md](networking.md).

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
