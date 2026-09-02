# 0006. HashiCorp Vault + Secrets Store CSI for CDE secrets

- Status: Accepted
- Date: 2026-09-02

## Context

Kubernetes Secrets are etcd objects. Even with KMS encryption at rest, they are world-readable to anyone who can `get secrets` in the namespace, they land in Velero backups, and they are a poor policy language for “only `cde-gateway` may decrypt PAN tokens.” PCI-DSS 4.0.1 Req. 3 wants stored account data protected with strong cryptography and key management.

[Vault Helm 0.34.1](https://github.com/hashicorp/vault-helm/releases/tag/v0.34.1) ships Vault **2.0.4** and vault-csi-provider **1.7.4**, and HashiCorp/IBM test Kubernetes 1.32–1.36 ([Helm docs](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm), [CSI docs](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/csi)). The CSI object is `SecretProviderClass` (`secrets-store.csi.x-k8s.io/v1`).

## Decision

- Run Vault in HA Raft mode, 3 replicas, anti-affinity across AZs, auto-unseal with the Terraform KMS key (`iam-addons.tf`).
- Consume secrets via **Secrets Store CSI** (tmpfs, not etcd). Vault Agent Injector is enabled as a fallback for apps that cannot mount CSI.
- Kubernetes/JWT auth: the Pod’s ServiceAccount is the Vault role. No static tokens in Git.
- PAN material lives in a Vault policy bound only to `cde-gateway`. Application DEKs for ledger encryption live in a policy bound to `cde-ledger`.
- Kubernetes Secrets are permitted only for Gateway TLS certs that controllers must read as Secret objects, and they are KMS-encrypted in etcd.

## Consequences

- We operate Raft, unseal (automated), snapshots (Velero + Vault raft snapshot to S3), and seal/unseal runbooks.
- CSI does not renew leases the way Vault Agent does; document rotation SLAs. Injector is available where lease renewal matters.
- Vault is **in the CDE** (it holds PAN ciphertext and keys). Its namespace, nodes, and IAM role are in-scope.
- External Secrets Operator is forbidden for CDE paths because it materializes etcd Secrets.

## Alternatives considered

- **AWS Secrets Manager + Secrets Store CSI.** Less operational load, IAM-native. Weaker policy language for “this SA, this path, this HTTP method,” and PAN would live in an AWS service we still have to scope. Rejected as the *CDE* store; acceptable for non-CHD platform secrets later.
- **External Secrets Operator.** Convenient for Helm `secretKeyRef`. Copies into etcd. Rejected for CDE.
- **Sealed Secrets / SOPS in Git.** Git becomes the backup of encrypted PAN. Wrong threat model (Git clones on laptops).
- **Plain Kubernetes Secrets + KMS.** Necessary for some controllers; insufficient for PAN.
- **Vault Secrets Operator (VSO).** Syncs to Kubernetes Secrets. Same etcd concern as ESO. CSI preferred.
