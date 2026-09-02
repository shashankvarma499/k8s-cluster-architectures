# Node failure runbook

Covers a single worker, a whole AZ of workers, and Karpenter disruption that looks like a failure. Control-plane (EKS API) AZ loss is AWS’s problem; verify with `kubectl get --raw='/readyz'` and the AWS health dashboard.

## 1. One node NotReady / terminated

**Symptoms:** `kubectl get nodes` shows `NotReady`, or the node object is gone. Pods in `Unknown` or `Terminating`.

**Expected automatic path** (do not page yet):

1. kubelet lease expires (~40 s).
2. Controller manager taints the node `node.kubernetes.io/unreachable:NoExecute`.
3. Pods with `terminationGracePeriod` are rescheduled. PDBs (`minAvailable: 2` on CDE) keep serving.
4. If the node was Karpenter-owned (`label karpenter.sh/registered=true`):
   - Spot interruption: SQS queue → Karpenter drains with the two-minute warning ([disruption](https://karpenter.sh/docs/concepts/disruption/)). CDE NodePool does not use Spot.
   - Instance failure: Karpenter sees the NodeClaim gone and launches a replacement for pending pods.

**Human checks (5 minutes):**

```bash
kubectl get nodes -L karpenter.sh/capacity-type,karpenter.sh/nodepool,topology.kubernetes.io/zone
kubectl get nodeclaims
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl -n cde-api get pdb,rollout
```

If pods stay Pending:

- `0/3 nodes available: 3 node(s) had untolerated taint pci.northstar.example/cde` — the CDE NodePool hit its CPU/memory `limits`. Raise them in `terraform/charts/karpenter-nodes` and `helm upgrade` (or wait for consolidation elsewhere).
- `didn't have free ports` / `Insufficient cpu` on system MNG — Karpenter should have launched; check `kubectl logs -n kube-system deploy/karpenter`.
- Image pull `403` from ECR — VPC endpoint or node IAM role.

**Do not** `kubectl delete node` unless the EC2 instance is already terminated and the object is stuck > 10 minutes. Deleting a live node skips graceful drain.

## 2. Whole AZ empty

**Symptoms:** `kubectl get nodes -L topology.kubernetes.io/zone` shows zero Ready nodes in one AZ. NAT CloudWatch `ErrorPortAllocation` or 5xx to KMS/ECR if that AZ’s NAT died *and* VPC endpoints are off.

**Expected:** topology spread `DoNotSchedule` means CDE replicas were already in the other two AZs. p99 may rise (lost `PreferSameZone` locality). RTO ≤ 5 min, RPO 0.

**Human:**

1. Confirm it is an AZ event (AWS Health, subnet ENI count) not a bad NodePool requirement that dropped that zone.
2. If NAT in that AZ is failed and `enable_vpc_endpoints = false`, image pulls fail for new pods. Either wait for NAT or temporarily pull from a replica AZ (endpoints are the fix; turn them on).
3. Do **not** lower `minAvailable` on PDBs to “make it schedule.” That is how you go to one replica in one AZ.
4. Karpenter will not replace capacity *in the dead AZ*. It will launch in healthy AZs. That is correct.

When the AZ returns, Karpenter consolidation on `platform` may pack back. CDE consolidation is `WhenEmpty` only, so CDE nodes in the recovered AZ appear only when new pods need them (scale-up or rolling deploy).

## 3. Karpenter consolidation looking like an outage

`WhenEmptyOrUnderutilized` on `platform` will cordon a node and drain it. CDE is `WhenEmpty`. If a payments pod was **mis-scheduled onto `platform`** (missing CDE toleration/nodeSelector), consolidation can drain it.

```bash
kubectl get pods -n cde-api -o wide
kubectl get pod -n cde-api <pod> -o jsonpath='{.spec.nodeName}{"\n"}{.spec.tolerations}{"\n"}'
```

Fix: the Rollout template must keep the CDE taint toleration. Gatekeeper does not check this; a unit test / Conftest in CI should.

## 4. System MNG node lost (Karpenter controller)

If two of three system nodes die in the same AZ event, Karpenter and Cilium operator still have one replica (PDB minAvailable 1 on metrics-server; Karpenter should be 2 replicas on 3 nodes). If **all** system nodes are gone, **no new nodes launch**.

Break-glass:

1. AWS console / CLI: the MNG is an Auto Scaling group named like `northstar-payments-system`. Set desired = 3.
2. Wait for Ready, then `kubectl -n kube-system get deploy karpenter`.
3. Pending CDE pods will then provision.

This is why `system_node_min_size = 3` and `az_count = 3`. Do not scale the MNG to 1 to save money.

## 5. Page / no-page

| Signal | Page? |
| --- | --- |
| Single Spot `platform` node interrupted | No |
| Single CDE node NotReady, replicas still ≥ PDB | No (ticket) |
| CDE Ready replicas < PDB `minAvailable` for > 2 min | Yes |
| Karpenter controller 0/2 and Pending CDE pods | Yes |
| AZ empty and error budget burning | Yes |
| EKS apiserver `readyz` fail | Yes (AWS + us) |

## 6. Aftercare

- `kubectl get events --sort-by=.lastTimestamp` and Hubble drops around the window → attach to the incident.
- If the node was terminated for a security finding (GuardDuty), do not just replace it; snapshot the instance (if still there) and follow IR.
- AMI alias `al2023@latest` may have rolled. Pin before the next ROC ([ADR 0012](../decisions/0012-cde-on-demand-nodes.md)).
