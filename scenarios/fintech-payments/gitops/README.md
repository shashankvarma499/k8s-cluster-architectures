# GitOps — Argo CD app-of-apps

Git is the desired state for everything that is not the VPC/EKS/Karpenter/Cilium floor (that is Terraform). This directory is what the root Application points at.

## Point it at this repo

1. Install Argo CD 3.5.2 (HA) after `terraform apply`:

   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm upgrade --install argocd argo/argo-cd --version 10.6.4 \
     --namespace argocd --create-namespace \
     --set redis-ha.enabled=true \
     --set controller.replicas=2 \
     --set server.replicas=2 \
     --set repoServer.replicas=2
   ```

   Official HA install YAML is also published: `https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/ha/install.yaml` ([release notes](https://github.com/argoproj/argo-cd/releases/tag/v3.5.2)).

2. Render the **bootstrap** Application (the only object you apply by hand) with *your* Git remote:

   ```bash
   helm template bootstrap charts/bootstrap \
     --set repoURL=https://github.com/YOUR_ORG/k8s-cluster-architectures \
     --set targetRevision=main \
     | kubectl apply -n argocd -f -
   ```

   `repoURL` must be a Git remote Argo CD can clone (HTTPS with a repo credential, or SSH). The default in `charts/bootstrap/values.yaml` is a placeholder GitHub URL — replace it before the first sync.

3. Argo CD then creates every child Application from `charts/app-of-apps`. AppProject `cde` is allowed to destinate only `cde-*` namespaces.

## Layout

| Path | Kind | Notes |
| --- | --- | --- |
| `charts/bootstrap/` | AppProject + root Application | Applied once |
| `charts/app-of-apps/` | One child Application per service | Synced by the root |
| `charts/payments-*/` | Sample CDE / token services | Stand-in nginx image |
| `namespaces/` | Namespaces + PSA labels | Standard Kubernetes; kubeconform |
| `networkpolicies/` | Default-deny + allowed edges | Standard NetworkPolicy |
| `poddisruptionbudgets/` | `minAvailable: 2` on CDE | Standard PDB |

CRDs (Application, Rollout, SecretProviderClass, TracingPolicy) live under `charts/` so CI `kubeconform` (which has no CRD schemas) skips them; `helm lint` still runs.

## Sync waves

| Wave | Application | Why |
| --- | --- | --- |
| `-3` | `platform-gatekeeper` | Admission before anything else |
| `-2` | `platform-rollouts`, `platform-vault`, `platform-tetragon` | CRDs and secrets before apps |
| `-1` | `platform-observability`, `platform-velero` | Analysis backend, backups |
| `0` | `payments-*`, `webhooks` | Workloads |

## Replace the stand-in image

Charts default to `public.ecr.aws/docker/library/nginx:1.27-alpine`. Override in the child Application:

```yaml
spec:
  source:
    helm:
      parameters:
        - name: image.repository
          value: 123456789012.dkr.ecr.us-west-2.amazonaws.com/payments-api
        - name: image.tag
          value: "1.4.2"
```

Do not put registry passwords in Git. Nodes pull via the node IAM role / ECR VPC endpoint.
