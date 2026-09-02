# Example app + where k3s shines

`hello.yaml` is a single-replica edge workload: Namespace `edge`, Deployment, Service (`LoadBalancer` via k3s ServiceLB), and an `Ingress` that stays dark until you install a controller.

## Why this shape

Edge and IoT sites rarely look like an EKS multi-AZ fleet. They look like **one box next to a sensor, a till, or a radio**. That is the niche k3s was built for ([k3s docs](https://docs.k3s.io/), [CNCF k3s](https://www.cncf.io/projects/k3s/)):

- **Small footprint.** One static binary, containerd included, SQLite by default. Fits a 1–2 vCPU industrial PC or a Raspberry-class ARM board. You do not run Karpenter, Istio, or a three-AZ NAT gateway here.
- **Offline-tolerant.** Air-gap install is a first-class path. SQLite + local-path provisioner means the node still schedules if the WAN dies. Reconnect later for GitOps.
- **API-compatible, not API-identical ops.** It is real Kubernetes (`Ingress`, `Deployment`, PSA labels), so the same manifest you test on kind/EKS can land on the factory floor. The *operations* are different: no cloud CCM, no EBS CSI unless you add one, Flannel instead of Cilium unless you opt in.
- **Fleet of clusters, not one fat cluster.** The usual edge pattern is many k3s sites plus a hub (this repo's EKS reference, or Cluster API) joined with GitOps and optionally [Cilium Cluster Mesh](https://docs.cilium.io/en/stable/network/clustermesh/). Do not stretch one etcd across a WAN.

## When k3s is the wrong default

- You need multi-AZ control-plane SLAs, IRSA, or Karpenter mixed Spot — use `clusters/eks`.
- You need a laptop multi-node kubeadm lookalike — use `clusters/kind`.
- You need hard multi-tenant isolation for untrusted teams — a virtual cluster or a real second cluster, not a second namespace on a 4 GB edge box.

Image `nginxdemos/hello:0.4` matches the kind playground so the two local clusters stay comparable.
