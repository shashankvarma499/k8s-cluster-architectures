# 0012. On-demand-only Karpenter NodePool for the CDE

- Status: Accepted
- Date: 2026-09-02

## Context

Karpenter makes mixed on-demand + Spot trivial: one NodePool, `karpenter.sh/capacity-type In [on-demand, spot]`, interruption queue drains on the two-minute warning. For *platform* workloads that is correct and cheap. For the cardholder data environment it is not:

- A Spot reclamation during an authorization burst is an SLO miss (p99 250 ms, 99.95% monthly).
- Shared-tenancy / noisy-neighbor questions appear in QSA interviews even on Nitro.
- Consolidation `WhenEmptyOrUnderutilized` will pack CDE pods onto a node and then replace it.

## Decision

- NodePool `cde`: `karpenter.sh/capacity-type In [on-demand]` only; taint `pci.northstar.example/cde=true:NoSchedule`; disruption `WhenEmpty`, `consolidateAfter: 5m`; `expireAfter: 720h` (forced recycle for patching).
- NodePool `platform`: on-demand + Spot, `WhenEmptyOrUnderutilized`, `consolidateAfter: 1m`.
- CDE Deployments/Rollouts tolerate the CDE taint and must **not** tolerate Spot taints. They set topology spread `DoNotSchedule` across zones.
- AMI selector is an alias in the lab (`al2023@latest`) and a **pinned** `al2023@vYYYYMMDD` in production.

## Consequences

- CDE compute bill is on-demand list (minus Savings Plans if we buy them on the node role).
- Patching is `expireAfter` + AMI pin bump, not in-place mut. PDBs keep auth up while nodes roll.
- A mislabeled Pod without the toleration stays Pending — fail-closed for scope.

## Alternatives considered

- **Spot with `on-demand` fallback and huge PDBs.** Still interrupts. Rejected for CDE.
- **Dedicated tenancy (`tenancy: dedicated` on EC2NodeClass).** Stronger isolation, large premium. Revisit if a QSA requires it; Nitro + taint is the current bar.
- **Separate cluster for CDE.** Strongest scope story, 2× EKS/NAT/system nodes. Rejected until a second tenant or a failed pentest of namespace segmentation forces it.
- **EKS Fargate for CDE pods.** No Cilium/Tetragon DaemonSets. Rejected.
