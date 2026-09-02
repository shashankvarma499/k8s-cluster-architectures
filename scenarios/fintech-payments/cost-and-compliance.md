# Cost optimization and PCI-DSS 4.0.1 mapping

Companion to [architecture.md](architecture.md). Numbers are order-of-magnitude **us-west-2 on-demand list**, September 2026, for a quiet weekday — not a quote. Spot, Savings Plans, and committed-use discounts move them.

## What actually costs money

| Line item | Shape | Quiet-day order of magnitude | Notes |
| --- | --- | --- | --- |
| EKS control plane | 1 cluster | ~$0.10/hour | Per cluster, not per AZ |
| NAT Gateway | 3 (one per AZ) | Dominant *fixed* network cost | Do not collapse to one NAT in production; that is an AZ failure. Use [VPC endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html) for S3, ECR, STS, KMS, Logs, EC2 to cut NAT bytes. |
| System MNG | 3 × `m6i.large` | Always-on | Karpenter cannot scale from zero without this island |
| CDE NodePool | on-demand `m/c/r` gen>2 | Scales with auth QPS | No Spot. Right-size with VPA **recommendations** + in-place resize ([stable](https://kubernetes.io/docs/concepts/workloads/pods/pod-resize/)) |
| Platform NodePool | on-demand + Spot | Prometheus/Loki/Argo | Spot interruption is acceptable here; PDB + Karpenter interruption queue |
| EBS gp3 | 50 GiB system, 40 GiB Karpenter, ledger PVCs | Encrypted | Snapshots are Velero’s volume path |
| S3 Velero + Loki + Tempo | versioned, replicated to us-east-1 | Storage + replication | 365-day audit log is CloudWatch → S3, not Loki |
| KMS | 2 CMKs (EKS secrets, Vault unseal) | Pennies + API calls |  |
| CloudWatch logs | five control-plane log types | Can surprise you | Set retention 365 days on `audit`; 90 days on the rest |
| Data transfer | AZ-crossing east-west | Real at Black Friday | `PreferSameZone` + topology spread exist to shrink this |

NAT + always-on system nodes + EKS are the floor. Everything else should scale to zero-ish with Karpenter consolidation.

## Cost knobs we turn (and the ones we do not)

**Turn:**

- **Karpenter consolidation** on `platform`: `WhenEmptyOrUnderutilized`, `consolidateAfter: 1m`. On `cde`: `WhenEmpty` only — do not bin-pack away a payments replica to save $0.04.
- **Spot on `platform` only.** `karpenter.sh/capacity-type in [on-demand, spot]` with on-demand fallback. CDE is on-demand ([ADR 0012](decisions/0012-cde-on-demand-nodes.md)).
- **Mixed instance types** (`c`, `m`, `r`, generation > 2). Karpenter picks the cheapest that fits the Pod.
- **VPC endpoints** for S3, ECR API, ECR DKR, STS, KMS, Logs, EC2, EKS. Image pulls and Velero uploads should not traverse NAT.
- **KEDA** for `webhook-dispatcher` and `fraud-engine` (queue depth). Scale to 1, not 0, if the SLO requires a warm replica; Kubernetes 1.37 HPA scale-to-zero is beta and not enabled here.
- **OpenCost / Kubecost** in the platform namespace. OpenCost 1.121 tracks GPU inference too, which we do not run yet. Allocate by namespace = PCI scope.
- **VPA in Off/recommendation mode.** Goldilocks-style reports, human applies. Auto-VPA on a JVM auth service is how you buy OOMs.

**Do not turn:**

- Single NAT Gateway.
- Spot in the CDE.
- Cluster Autoscaler “just for the CDE ASG” — two autoscalers is two sources of drain.
- Retention of Loki at 15 days to save S3. Operational logs can be 90 days; **audit** logs cannot (Req. 10).
- Fargate for the CDE. DaemonSets (Cilium, Tetragon, CSI) do not run there; AWS’s current guidance is [Auto Mode instead](https://docs.aws.amazon.com/eks/latest/userguide/auto-migrate-fargate.html).

### Rough monthly floor (quiet)

Three NAT Gateways, three `m6i.large`, one EKS control plane, KMS, a few hundred GB of logs: **low four figures USD** before CDE replicas and observability storage. Black Friday is a Karpenter problem, not a capacity ticket, as long as EC2 quota and NodePool limits (`cpu: "1000"`) are honest.

## PCI-DSS 4.0.1 control mapping

This table maps the twelve PCI-DSS 4.0.1 requirements to concrete objects in this scenario. It is a **starting point for a QSA conversation**, not a Report on Compliance. Official text lives in the [PCI SSC document library](https://www.pcisecuritystandards.org/document_library/). Microsoft’s [AKS PCI 4.0.1 series](https://learn.microsoft.com/en-us/azure/aks/pci-intro) and AWS’s [PCI on EKS blog](https://aws.amazon.com/blogs/containers/building-pci-dss-compliant-architectures-on-amazon-eks/) informed the Kubernetes-specific rows.

| Req. | Intent | How this platform addresses it | Evidence |
| --- | --- | --- | --- |
| 1 | Network security controls | VPC, one NAT per AZ, no 0.0.0.0/0 on the API in production, default-deny NetworkPolicy, Cilium identity, Gateway HTTPS-only, security groups on ENIs | `gitops/networkpolicies/*`, Hubble flows, SG rules, pentest of the CDE boundary (11.4.5) |
| 2 | Secure configurations | Bottlerocket or AL2023 EKS AMI, IMDS hop limit 2 + tokens required, PSA Restricted, Gatekeeper (no privileged, non-root, requests/limits), no vendor defaults on Vault | EC2NodeClass, PSA labels, `policies/` |
| 3 | Protect stored account data | PAN tokenized at gateway; token↔PAN map in Vault; no PAN on PVCs; etcd Secrets KMS-encrypted; S3 SSE-KMS for backups | Vault policy, CSI mounts, KMS key policy. **Do not store PAN in Git, ConfigMaps, or logs.** |
| 4 | Protect CHD in transit | TLS 1.2+ on Gateway listeners; mTLS to Vault; in-cluster east-west is still cluster-network — Cilium L7 policy on the gateway→api path; no plaintext Ingress | Gateway spec, Gatekeeper `K8sHttpsOnly` / `K8sGatewayHttpsOnly` |
| 5 | Anti-malware | Minimal AL2023 AMI, no SSH (SSM), Tetragon kills unexpected exec, image provenance (Cosign in CI — Kyverno ImageValidatingPolicy is the next step) | Tetragon TracingPolicy, AMI pin |
| 6 | Secure software | GitOps (no kubectl snowflakes), Argo Rollouts canary, Gatekeeper admission, Dependabot/CI kubeconform, no `latest` tags in committed charts | Argo history, CI, Rollout Analysis |
| 7 | Access by need-to-know | EKS access entries / IRSA, Argo CD AppProjects (`cde` vs `platform`), Vault policies per ServiceAccount, RBAC in CDE namespaces is empty for humans (break-glass only) | IAM, AppProject, Vault policy |
| 8 | Identify and authenticate | SSO to Argo CD and AWS IAM Identity Center; MFA on the IdP (PCI 4.0.1 requires MFA for *all* CDE access); no long-lived AWS keys in CI (OIDC) | IdP config, CloudTrail |
| 9 | Physical | AWS data centers — inherited. SSM instead of bastion SSH. No local disk with PAN. | AWS PCI AoC / responsibility matrix |
| 10 | Log and monitor | EKS audit logs → CloudWatch (365 days) → S3; Hubble; Tetragon; Prometheus/Loki/Tempo; GuardDuty EKS Protection recommended (account-level, not in this Terraform) | CloudWatch retention, Velero of Loki is *not* the audit trail |
| 11 | Test security | Quarterly ASV + annual pentest; **segmentation pentest** of CDE NetworkPolicy; Gatekeeper dry-run then deny; chaos of node failure (see runbook) | Pentest report, this repo is not that report |
| 12 | Policies | ADRs in `decisions/`, runbooks, scoped CDE diagram in architecture.md, six-month NetworkPolicy review (Req. 1.2.7) | This directory |

### Scoping rules of thumb

1. If a process can see PAN, it is CDE.
2. If a process can *change* what the CDE runs (Argo CD, Gatekeeper, the EKS API, Karpenter on the `cde` pool), it is connected-to and in the ROC.
3. If a process can only see tokens *and* NetworkPolicy + SG + pentest prove it cannot reach CDE sockets, it is out of scope.
4. Logs that might contain PAN are CDE. Redact at the source; do not rely on Loki access control as the scope boundary.
5. Backups of CDE volumes are CDE. The Velero bucket is in-scope storage.

### Audit logging (Req. 10) in practice

| Stream | Destination | Retention | Who can delete |
| --- | --- | --- | --- |
| Kubernetes API audit | CloudWatch log group `/aws/eks/<cluster>/cluster` type `audit` | 365 days | Security account only (log-group policy) |
| Authenticator | CloudWatch `authenticator` | 365 days | Same |
| Hubble flows (CDE ns) | Loki + optional S3 export | 90 days operational | Platform + security |
| Tetragon process exec | Loki (JSON) | 90 days | Security |
| Application logs | Loki, PAN-redacted | 90 days | Platform |
| Vault audit | Vault audit device → S3 | 365 days | Security |

Workload teams do not have `logs:DeleteLogGroup` on the audit groups. That is the “tamper-proof” bar PCI 4.0.1 tightened for ephemeral compute.

## Cost vs compliance conflicts (resolve them this way)

| Temptation | Why it is cheaper | Why we do not |
| --- | --- | --- |
| One NAT | ~⅔ NAT bill gone | AZ failure blacks out ECR/KMS/S3 without endpoints; even *with* endpoints, non-AWS egress dies |
| Spot in CDE | 60–70% compute | 2-minute interruption during an authorization burst is an SLO miss; QSA will ask about noisy neighbors |
| Shared nodes CDE + platform | Higher bin-pack | One debug sidecar and the node is in-scope forever |
| Disable Hubble | CPU | Hubble *is* the Req. 1 evidence |
| Skip Velero replica | S3 replication $ | Region RPO becomes “whatever is in us-west-2” |
| `latest` AMI alias | No pin work | Unexplained node replacement the night before a ROC |

## When this mapping is not enough

You still need: a named QSA, an ASV, a pentest of the CDE boundary, an AWS PCI responsibility matrix, a Vault production hardening review, and an incident-response plan that names who unseals Vault at 03:00. This repository gives them something to assess instead of a whiteboard.
