# 0011. Gateway API for north-south traffic

- Status: Accepted
- Date: 2026-09-02

## Context

The community [ingress-nginx controller retired in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) and no longer receives security patches. New north-south work should not land on Ingress annotations. [Gateway API v1.6.1](https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/) Standard channel includes HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, UDPRoute, and ListenerSet. Cilium 1.20 ships Gateway API 1.6.1 support. AWS Load Balancer Controller also implements Gateway API for NLB/ALB.

PCI Req. 4: CHD in transit is encrypted. HTTP listeners on the public Gateway are a finding.

## Decision

- Expose `payments-gateway` through a `Gateway` + `HTTPRoute` (`gateway.networking.k8s.io/v1`), HTTPS listener only, certificates from cert-manager or ACM via the AWS controller.
- Do not install ingress-nginx.
- Gatekeeper `K8sHttpsOnly` (library) on Ingress leftovers; `K8sGatewayHttpsOnly` (ours) on Gateway listeners.
- Prefer Cilium’s Gateway API implementation for in-cluster policy cohesion; AWS LBC is acceptable if we need ACM-native certs on an NLB. Pick one controller per GatewayClass.

## Consequences

- Teams write HTTPRoute, not Ingress. The annotation zoo goes away.
- We must run a Gateway controller (Cilium or AWS LBC) and grant it ReferenceGrant to the TLS Secret.
- Some vendor Helm charts still emit Ingress. Gatekeeper rejects HTTP; they must be wrapped or replaced.

## Alternatives considered

- **Keep ingress-nginx.** Unpatched. Unacceptable on a CDE.
- **AWS ALB Ingress Controller annotations only.** Works, proprietary, not the 2026 portable API.
- **Istio Gateway.** Ties north-south to a mesh we have not adopted ([ADR 0003](0003-cilium-cni-networkpolicy.md)).
- **Service type LoadBalancer per app.** One NLB each, no L7 routing, expensive, still needs TLS somewhere.
