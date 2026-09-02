# 0003. Cilium CNI chained on VPC CNI, with NetworkPolicy microsegmentation

- Status: Accepted
- Date: 2026-09-02

## Context

PCI-DSS 4.0.1 Req. 1 wants restricted CDE traffic and a documented, pentestable boundary. Kubernetes default is full-open Pod networking. Amazon VPC CNI gives ENI IPs and security groups but its NetworkPolicy implementation is not the eBPF identity model we want for Hubble evidence. Cilium 1.20 (chart 1.20.1, 18 August 2026) is the CNCF-graduated eBPF CNI: NetworkPolicy, CiliumNetworkPolicy (L3–L7), Hubble, optional kube-proxy replacement and Gateway API ([Cilium docs](https://docs.cilium.io/en/stable/), [Helm EKS install](https://docs.cilium.io/en/stable/installation/k8s-install-helm/)).

## Decision

- Install **Cilium 1.20.1** with `cni.chainingMode=aws-cni`, `cni.exclusive=false`, `routingMode=native`, `enableIPv4Masquerade=false`, Hubble relay on, operator replicas = 2.
- Keep Amazon VPC CNI as the IPAM/ENI owner so the managed node group becomes Ready in one `terraform apply`.
- Enforce Kubernetes `NetworkPolicy` default-deny in every CDE namespace (manifests in [`gitops/networkpolicies`](../gitops/networkpolicies)). Add `CiliumNetworkPolicy` only where we need L7 (HTTP method/path on gateway→api).
- Do not enable Cilium Cluster Mesh on the primary cluster until a documented read-failover use case exists.

## Consequences

- Identity-aware policy + Hubble flows are the Req. 1 / 11.4.5 evidence.
- Two CNIs on the node. Chaining is a supported EKS pattern; exclusive ENI mode is a later migration (`eni.enabled=true`, remove vpc-cni, re-IP).
- kube-proxy still runs until we flip Cilium kube-proxy replacement. That flip is a maintenance window, not a Helm default.
- Hubble is in-scope for CDE namespaces (it sees headers if L7 policy is on). Keep L7 policy narrow.

## Alternatives considered

- **VPC CNI NetworkPolicy only.** Ships with EKS, now has admin/baseline/application tiers ([AWS PCI-on-EKS](https://aws.amazon.com/blogs/containers/building-pci-dss-compliant-architectures-on-amazon-eks/)). Weaker Hubble equivalent; we already standardized on Cilium in this repo.
- **Calico.** Mature NetworkPolicy. Not eBPF-first; Tetragon pairs naturally with Cilium.
- **Cilium exclusive ENI on day one.** Cleaner datapath, more install risk (nodes not Ready until Cilium is). Rejected for apply-in-one-shot; accepted as a follow-up ADR.
- **Istio sidecar / ambient as the segmentation layer.** Mesh identity is complementary, not a replacement for NetworkPolicy. Ambient expands PCI scope to ztunnel. Deferred.
