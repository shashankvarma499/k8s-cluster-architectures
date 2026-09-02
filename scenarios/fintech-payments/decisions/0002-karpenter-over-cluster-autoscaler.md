# 0002. Karpenter v1 instead of Cluster Autoscaler

- Status: Accepted
- Date: 2026-09-02

## Context

Authorization QPS is spiky (20× on Black Friday). The cluster must add capacity in tens of seconds, pack mixed instance types, and use Spot for **out-of-scope** workloads. Cluster Autoscaler scales pre-created node groups. Karpenter launches the instance the pending Pod actually needs. EKS Auto Mode is AWS’s managed Karpenter.

Karpenter **1.14.1** (21 August 2026) is the current LTS line and supports Kubernetes 1.29–1.36 ([endoflife.date](https://endoflife.date/karpenter), [karpenter.sh](https://karpenter.sh/)). The stable API is `NodePool` (`karpenter.sh/v1`) + `EC2NodeClass` (`karpenter.k8s.aws/v1`). `Provisioner` / `AWSNodeTemplate` are gone ([v1 migration](https://karpenter.sh/docs/upgrading/v1-migration/)).

## Decision

- Install Karpenter 1.14.1 via the OCI charts `oci://public.ecr.aws/karpenter` (`karpenter-crd` then `karpenter`), using the `terraform-aws-modules/eks/aws//modules/karpenter` submodule for IAM, SQS interruption, and the node role.
- Run the controller on the system managed node group (`karpenter.sh/controller=true`).
- Two NodePools: `cde` (on-demand, CDE taint) and `platform` (on-demand + Spot). See [ADR 0012](0012-cde-on-demand-nodes.md).
- Do **not** install Cluster Autoscaler.
- Do **not** put CDE workloads on EKS Auto Mode until we can express the same taint and AMI pin.

## Consequences

- Scale-up is typically tens of seconds on EC2 Fleet, not minutes on an ASG.
- Instance types are not known ahead of time; PDBs and topology spread are mandatory so consolidation cannot drain a zone.
- Destroy is operator-careful: NodePools are not in Terraform state. Drain them first ([clusters/eks gotcha](../../../clusters/eks/README.md)).
- Spot interruption handling is built in (SQS queue). CDE never subscribes to Spot.

## Alternatives considered

- **Cluster Autoscaler.** Portable, group-oriented, well understood. Rejected because mixed-type + Spot-in-the-same-pool is several ASGs and a node-termination handler we would have to run ourselves. Still the right tool on GCP/Azure if we leave AWS.
- **EKS Auto Mode.** Recommended by AWS for new clusters ([best practices](https://docs.aws.amazon.com/eks/latest/best-practices/automode.html)). Rejected as the CDE pool: less visible NodeClass, harder ROC story. Eligible for `platform` later.
- **EKS Fargate.** No DaemonSets (Cilium, Tetragon, CSI). AWS tells new workloads to [migrate Fargate → Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-migrate-fargate.html).
- **Fixed node groups sized for Black Friday.** Simple, expensive, still needs an AZ-failure buffer.
