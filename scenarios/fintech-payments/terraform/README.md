# Terraform — Northstar Payments EKS

Root module that provisions the **infrastructure Argo CD cannot create**: VPC (3 AZs, NAT per AZ, flow logs, VPC endpoints), EKS 1.34, Karpenter 1.14.1, Cilium 1.20.1 chained on the VPC CNI, KMS (Vault unseal + audit), Velero S3 + replica, IRSA for Velero and Vault.

It follows the same module pins as [`clusters/eks`](../../../clusters/eks) (`terraform-aws-modules/eks/aws ~> 20.37`, `vpc/aws ~> 5.21`, AWS provider 5.x) and is self-contained — copy this directory and it still applies.

## Layout

| File | Contents |
| --- | --- |
| `vpc.tf` | VPC, 3 AZs, public + private + intra, NAT per AZ, flow logs, endpoints |
| `eks.tf` | EKS 1.34, IRSA, system MNG × 3, vpc-cni/kube-proxy/coredns/pod-identity/snapshot-controller, `module.addons` |
| `karpenter.tf` | Controller IAM (Pod Identity + IRSA), node role, SQS interruption, Helm `karpenter-crd` + `karpenter` + NodePools |
| `kms.tf` | Vault unseal CMK, audit CMK (CloudWatch + Velero) |
| `s3.tf` | Velero bucket, SSE-KMS, versioning, CRR to `dr_region` |
| `iam-addons.tf` | IRSA roles for `velero:velero` and `vault:vault` |
| `addons/` | Cilium 1.20.1 + metrics-server 3.13.0 |
| `charts/karpenter-nodes/` | `EC2NodeClass` + NodePools `cde` and `platform` |

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# lock cluster_endpoint_public_access_cidrs

terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Then bootstrap GitOps from [`../gitops/README.md`](../gitops/README.md).

## Destroy

```bash
kubectl delete nodepool --all --wait=true
kubectl delete ec2nodeclass --all --wait=true
terraform destroy
```

Karpenter-created EC2 is not in Terraform state. See [`clusters/eks` teardown](../../../clusters/eks/README.md).
