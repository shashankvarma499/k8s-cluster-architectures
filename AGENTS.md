# AGENTS.md — Build Brief for AI Coding Agents

This file is the authoritative spec for any AI agent working in this repo. Read
it fully before writing any files.

## Mission

Document **cutting-edge Kubernetes cluster architecture** (2025–2026 state of
the art), ship a **playable example cluster** a newcomer can spin up locally in
minutes, and include a **real-world production scenario** with full IaC. All
content must be technically accurate, current, and copy-paste runnable where it
claims to be.

## Repo layout (do not deviate)

```
docs/
  architecture/          # one .md per topic (deep-dives)
  decisions/             # ADRs (NNNN-short-title.md)
clusters/
  kind/                  # local playground (kind + Helm), fully runnable
  k3s/                   # lightweight single-node/edge cluster
  eks/                   # production EKS reference in Terraform
scenarios/
  fintech-payments/      # real-world HA/multi-AZ/DR scenario (IaC + ADRs)
.github/
  workflows/             # CI: lint + validate every manifest
scripts/                 # reusable helper scripts
```

## Content standards (non-negotiable)

1. **Accurate & current.** Reflect the K8s ecosystem as of 2026. Cite sources
   (upstream docs, CNCF blog, KEPs) as inline links. Do not invent features,
   versions, or flags.
2. **Valid YAML/Helm/Terraform.** Every manifest must pass `kubeconform`,
   `helm lint`, and `terraform fmt -check`/`validate` as appropriate. No
   placeholder `<...>` values in committed manifests — use concrete defaults.
3. **Runnable.** `clusters/kind` must come up end-to-end with
   `./up.sh` on a machine with Docker + kind + kubectl + helm. Provide a
   `README.md` in each cluster/scenario dir with prerequisites and commands.
4. **Diagrams.** Prefer Mermaid diagrams (render natively on GitHub) for
   architecture and network topologies.
5. **Concise but deep.** Each doc should be a focused deep-dive, not a wall of
   boilerplate. Include "when to use / when NOT to use / trade-offs / gotchas".

## Cutting-edge topics that MUST be covered in `docs/architecture/`

- Control-plane & node lifecycle: **Cluster API**, **Karpenter** (vs Cluster
  Autoscaler), managed autopilot-style node pools (GKE Autopilot, EKS Fargate).
- Networking: **eBPF-based CNI (Cilium)**, **Gateway API**, service mesh
  evolution (**Istio ambient mesh**, Cilium Service Mesh) vs sidecar.
- Multi-tenancy & isolation: **vCluster** / virtual clusters, hard multi-tenancy
  patterns, namespace-as-a-service.
- Workloads: **AI/ML on K8s** (GPU scheduling, Kueue, DRA — Dynamic Resource
  Allocation), KubeVirt (VMs on K8s), edge (K3s/KubeEdge).
- Security: Pod Security Admission, OPA/Gatekeeper, Kyverno, **Tetragon**
  (eBPF runtime security), secrets (Secrets Store CSI, external providers).
- Delivery & operations: GitOps (**Argo CD**/Flux), progressive delivery (Argo
  Rollouts), policy-as-code, cost optimization (KEDA, Kubecost, VPA).
- Multi-cluster & resilience: Cilium Cluster Mesh, cluster fleet management,
  backup/DR (**Velero**), topology-aware scheduling, PDBs.

## The real-world scenario (`scenarios/fintech-payments/`)

Model a production **payment-processing platform** (or similar regulated
workload). It must demonstrate, with real IaC and ADRs:

- Multi-AZ, highly-available control plane and data plane.
- Karpenter-driven autoscaling with mixed instance types + spot fallback.
- Cilium CNI + NetworkPolicy microsegmentation (PCI-DSS flavored).
- GitOps delivery via Argo CD (app-of-apps), progressive rollout via Argo
  Rollouts.
- Observability: OpenTelemetry + Prometheus/Grafana + Loki + Tempo.
- Security: OPA/Gatekeeper policies, Pod Security Admission, Vault or
  equivalent for secrets, runtime defense (Tetragon).
- Disaster recovery: Velero backups + restore runbook, RTO/RPO targets.
- Cost & compliance notes (PCI-DSS scope, audit logging).

Each ADR must follow: **Context → Decision → Consequences → Alternatives
considered**.

## Git & commit conventions

- Conventional Commits (`docs:`, `feat:`, `fix:`, `ci:`).
- Write files, but **do NOT `git push`** unless explicitly instructed. The
  orchestrating agent handles commits/pushes/PRs.
- Do not commit secrets, `.env`, or credentials of any kind.

## Definition of done

- `clusters/kind/up.sh` brings up a working cluster (verified by the agent
  running `kubectl get nodes` where Docker is available).
- Every `.yaml`/`.yml` in the repo passes validation; Terraform is `fmt`+`plan`-clean.
- `docs/architecture/` covers every topic listed above with cited sources.
- `scenarios/fintech-payments/` contains IaC + ADRs + a runbook.
- `.github/workflows/` validates all of the above in CI.
