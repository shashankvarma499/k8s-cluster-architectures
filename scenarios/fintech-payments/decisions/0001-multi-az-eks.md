# 0001. Multi-AZ Amazon EKS for the payments control plane

- Status: Accepted
- Date: 2026-09-02

## Context

Northstar Payments needs a Kubernetes control plane that survives the loss of one Availability Zone without human action, and a data plane that can reschedule authorization pods in the remaining AZs. We could run kubeadm on EC2, Cluster API (CAPA), GKE, AKS, or Amazon EKS. PCI-DSS 4.0.1 does not name a vendor, but it does require that in-scope systems stay available enough to keep compensating controls (logging, firewall, access) running during a failure.

EKS Kubernetes **1.34** is in standard support through 2026-12-02 ([version calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)). 1.35 and 1.36 are also in standard support; 1.33 is extended-only.

## Decision

Run **Amazon EKS 1.34** in `us-west-2` with:

- Three AZs for private, public, and intra subnets.
- Private API endpoint always on; public endpoint CIDR-locked (off in production).
- All five control-plane log types enabled.
- KMS CMK encryption of Kubernetes Secrets.
- Control-plane ENIs in intra subnets; nodes in private subnets.
- One NAT Gateway per AZ.

Terraform lives in [`terraform/`](../terraform/) and follows the same module versions as [`clusters/eks`](../../../clusters/eks) (`terraform-aws-modules/eks/aws ~> 20.37`, AWS provider 5.x).

## Consequences

- AZ failure of compute or NAT does not take down the API or egress.
- We inherit AWS’s PCI responsibility matrix for the managed control plane; we still own everything in the data plane.
- EKS 1.34 is N-1 relative to 1.36. We upgrade after Cilium, Karpenter, Vault CSI, and Gatekeeper list 1.35/1.36 in their matrices — Karpenter 1.14.1 already lists through 1.36 ([compatibility](https://endoflife.date/karpenter)).
- Intra subnets add a CIDR to manage; they keep control-plane ENIs off node subnets.

## Alternatives considered

- **kubeadm on EC2 / Cluster API CAPA.** Full control, full etcd on-call. Wrong staffing model for one payments cluster. Revisit when we need a fleet CRD.
- **EKS Auto Mode.** AWS-managed Karpenter + Bottlerocket. Rejected as the *only* data plane because CDE taints and AMI pins must be QSA-explainable ([ADR 0002](0002-karpenter-over-cluster-autoscaler.md)). Compatible later as a *platform* pool.
- **GKE Autopilot / AKS.** Fine products; the org’s card-network connectivity and IAM already live in AWS.
- **Two AZs.** Cheaper. A two-AZ etcd/API still works; a two-AZ data plane plus one NAT failure is an outage. Three is the payments default.
- **Kubernetes 1.36 on day one.** Newest EKS standard. Higher add-on risk for a ROC window. We will move 1.34 → 1.35 in the next maintenance train.
