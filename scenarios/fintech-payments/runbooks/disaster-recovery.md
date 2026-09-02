# Disaster recovery runbook (Velero)

**RTO / RPO** (from [architecture.md](../architecture.md)):

| Scenario | RTO | RPO | Who |
| --- | --- | --- | --- |
| AZ failure | ≤ 5 min | 0 | Automatic (multi-AZ + PDB + Karpenter) |
| In-region cluster rebuild | 2 hours | 1 hour | Human + Velero |
| Region loss (`us-west-2`) | 4 hours | 15 minutes | Human; Terraform in `us-east-1` + S3 replica |

Velero restores **into a cluster that already exists**. It is not Cluster API. CRDs are `velero.io/v1` ([BackupStorageLocation](https://velero.io/docs/main/api-types/backupstoragelocation)).

## 0. Preconditions

- Terraform state for the primary is readable (or you can re-apply from `terraform.tfvars`).
- Velero S3 replica in `dr_region` (`terraform output velero_bucket_replica`) has the latest objects. CRR lag is typically seconds; **do not fail over on a backup older than 15 minutes** without an incident commander decision.
- Vault unseal KMS key is in the primary region. For region loss you need a **Vault raft snapshot** in the replica bucket (Velero includes the `vault` namespace) *and* a KMS replica or a re-init. Treat Vault restore as the long pole.
- DNS for `pay.northstar.example` is in a global zone (Route 53) you can update.

## 1. In-region restore (cluster still in `us-west-2`)

Use this when Git is fine but etcd/volumes are not (bad apply, namespace delete, ransomware of PVCs).

1. Confirm the cluster API is healthy:

   ```bash
   kubectl get --raw='/readyz?verbose'
   kubectl get nodes
   kubectl -n velero get backup,schedule,backupstoragelocation
   ```

2. List backups:

   ```bash
   kubectl -n velero get backup -o wide
   # or: velero backup get
   ```

3. Restore CDE namespaces **excluding** Terraform-owned resources:

   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: velero.io/v1
   kind: Restore
   metadata:
     name: cde-restore
     namespace: velero
   spec:
     backupName: cde-hourly-<timestamp>
     includedNamespaces:
       - cde-gateway
       - cde-api
       - cde-ledger
       - vault
     excludedResources:
       - nodes
       - events
       - events.events.k8s.io
       - backups.velero.io
       - restores.velero.io
     restorePVs: true
     existingResourcePolicy: update
   EOF
   ```

   Replace `cde-hourly-<timestamp>` with the backup name from step 2. Do **not** restore `kube-system`, `NodePool`, or `EC2NodeClass` — Terraform owns those.

4. Watch:

   ```bash
   kubectl -n velero get restore cde-restore -o yaml
   kubectl get pods -n cde-api -n cde-gateway -n cde-ledger -n vault
   ```

5. Unseal Vault if Raft came back sealed (`vault operator unseal` is not needed with auto-unseal; `vault status` should show `Sealed: false` once the KMS endpoint is reachable).

6. Confirm Gatekeeper constraints are still `deny` and Hubble still shows default-deny drops from `fraud` → `cde-api`.

7. Authorization smoke test (synthetic PAN in a **non-prod** merchant, never a live card).

**Stop condition:** Restore `phase: PartiallyFailed` with PVC errors. Do not cut traffic. File-system backup is not enabled for CDE; a failed CSI snapshot restore is a data incident, not a “retry with --default-volumes-to-fs-backup”.

## 2. Region failover (`us-west-2` → `us-east-1`)

Target: RTO 4 h, RPO 15 min.

1. **Declare the incident.** Freeze Git deploys (Argo CD manual sync only).
2. Apply Terraform in the DR region with a **new cluster name** (`northstar-payments-dr`) and `region = "us-east-1"`. Wait for system nodes, Cilium, Karpenter.

   ```bash
   cd terraform
   terraform workspace new dr   # or a separate state
   # set region = "us-east-1", cluster_name = "northstar-payments-dr"
   terraform apply
   ```

3. Install Velero pointing at the **replica bucket** (`velero_bucket_replica`) with the DR IRSA role. `BackupStorageLocation` `config.region` is `us-east-1`.

4. `velero backup get` should list replicated backups (backup sync period; wait up to a few minutes).

5. Restore as in §1 into the new cluster.

6. Vault: if auto-unseal KMS is regional, you cannot unseal with the `us-west-2` key from `us-east-1`. Options, in order:
   - Use a **multi-region KMS key** (follow-up to this Terraform; not on by default).
   - Restore Vault from a raft snapshot and unseal with a **DR KMS key** that was a replica.
   - Initialize a new Vault and restore KV from an application-level export (RPO becomes last KV snapshot).

   Do not skip this step and “just ship the API”: the gateway cannot tokenize.

7. Point Route 53 `pay.northstar.example` at the DR NLB / Gateway. TTL should already be ≤ 60 s.

8. Keep the primary cluster (if it still exists) **read-only**: scale `payments-api` to 0 so you do not dual-write the ledger.

9. Post-incident: Git `targetRevision` stays the same; Argo CD in DR is bootstrapped from [gitops/README.md](../gitops/README.md).

## 3. What Velero does not restore

- EC2 instances, VPC, NAT, IAM, KMS. Terraform.
- Prometheus TSDB. Rebuilt.
- In-flight authorizations. Those are lost; issuers time out. RPO is for **durable** ledger state.
- PAN in Vault if the snapshot is older than the last tokenize. Treat as a Req. 3 incident and rotate tokens.

## 4. Game days

Run §1 in a **non-prod** clone quarterly. Run §2 annually. PCI 4.0.1 Req. 11.4.5 (segmentation pentest) is a different exercise; do not combine them.
