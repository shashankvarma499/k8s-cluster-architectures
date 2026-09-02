# k8s-cluster-architectures

Cutting-edge Kubernetes cluster architectures, playable example clusters, and a
real-world production scenario — curated and kept current by an automated
research agent.

## What's inside

| Path | What it is |
|------|------------|
| `docs/architecture/` | Deep-dives on modern K8s architecture patterns and tools |
| `docs/decisions/` | Architecture Decision Records (ADRs) |
| `clusters/kind/` | Local playable cluster (Kubernetes-in-Docker) — start here |
| `clusters/k3s/` | Lightweight single-node / edge cluster |
| `clusters/eks/` | Production EKS reference (Terraform) |
| `scenarios/fintech-payments/` | Real-world HA / multi-AZ / DR scenario |
| `.github/workflows/` | CI to lint & validate every manifest in the repo |

## Quick start (local playground)

```bash
# Requires: Docker + kind + kubectl + helm (see clusters/kind/README.md)
cd clusters/kind
./up.sh        # creates a kind cluster and installs the example stack
./down.sh      # tears it down
```

## Real-world scenario

See [`scenarios/fintech-payments/`](scenarios/fintech-payments/) — a payment
platform architecture with multi-AZ HA, Karpenter autoscaling, Cilium
networking, GitOps via Argo CD, observability, security hardening, and disaster
recovery.

## How this repo is maintained

An automated agent periodically scans for new Kubernetes architecture
developments (CNCF projects, upstream K8s releases, notable production
post-mortems) and opens PRs to keep this content current.

## License

MIT
