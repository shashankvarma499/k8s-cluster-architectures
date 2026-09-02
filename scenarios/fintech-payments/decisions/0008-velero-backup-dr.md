# 0008. Velero for backup and disaster recovery

- Status: Accepted
- Date: 2026-09-02

## Context

EKS HA covers an AZ. It does not cover “we applied a Gatekeeper constraint that deleted the CDE” or “us-west-2 is on fire.” We need object + volume backup with a documented restore into a *new* cluster. [Velero](https://velero.io/) is the portable tool: `Backup` / `Restore` / `Schedule` / `BackupStorageLocation` are `velero.io/v1`. CSI snapshots (preferred) plus upload to S3; File System Backup (node-agent) is the fallback for volume types without snapshots. AWS also offers Backup for EKS; Velero remains the one we can restore onto a cluster we built with Terraform in another region.

RPO/RTO targets are in [architecture.md](../architecture.md): in-region restore RTO 2 h / RPO 1 h; region failover RTO 4 h / RPO 15 min.

## Decision

- Install Velero (Helm `vmware-tanzu/velero`, CRDs `velero.io/v1`) with the AWS plugin, **CSI snapshots enabled**, File System Backup **off** for CDE volumes.
- Terraform creates a versioned, SSE-KMS, public-blocked S3 bucket and an IRSA role. Cross-region replication to `us-east-1` is on.
- `Schedule` `cde-hourly` at `:00` for namespaces `cde-gateway`, `cde-api`, `cde-ledger`, `vault`. TTL 720 h (30 days).
- `Schedule` `platform-daily` for `argocd`, `observability` (exclude Prometheus TSDB; it is rebuilt).
- Restore runbook: [runbooks/disaster-recovery.md](../runbooks/disaster-recovery.md). Velero does not create the cluster; Terraform does.
- Exclude `kube-system` NodePools/EC2NodeClass from restore (Terraform owns them).

## Consequences

- Volume restore is crash-consistent *if* the CSI driver snapshot is. Ledger writes must still fsync; we do not pretend a snapshot is a database PITR. Application-level backup (SQL dump / WAL) is a follow-up if the ledger moves to Aurora.
- The bucket contains Secrets and Vault snapshots → **CDE storage**. Replication destination too.
- Restore time is dominated by EBS snapshot copy + Vault unseal, not by `velero restore`.
- Hourly backups miss up to 59 minutes of GitOps-applied config; Git is the real config backup. Velero is for cluster state + volumes.

## Alternatives considered

- **AWS Backup for EKS.** Managed, less portable. Rejected as the only tool; complementary later.
- **Git only.** Recreates YAML, not PVCs or Vault Raft.
- **etcd snapshots by hand.** We do not have etcd; EKS does. Not available to us.
- **File System Backup (Kopia) for everything.** Not crash-consistent; node-agent is another privileged DaemonSet in the CDE. Rejected for CDE volumes.
- **Active-active Cluster Mesh.** Consistency risk on the ledger. Rejected for capture/auth ([architecture.md](../architecture.md)).
