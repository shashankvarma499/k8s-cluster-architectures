# 0009. Pod Security Admission Restricted + OPA Gatekeeper

- Status: Accepted
- Date: 2026-09-02

## Context

Pod Security Admission (PSA) has been the in-tree replacement for PodSecurityPolicy since 1.25 ([docs](https://kubernetes.io/docs/concepts/security/pod-security-admission/)). Restricted is the 2026 default for app namespaces: no root, no host namespaces, drop caps, seccomp RuntimeDefault. PSA does not cover “must have CPU/memory requests and limits,” “Ingress must be TLS,” or “no privileged.”

[Kyverno](https://kyverno.io/) graduated CNCF on 16 March 2026 and is the YAML-native policy engine. [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) remains the Rego engine. This org already writes Rego for Terraform (Conftest) and wants one language. Gatekeeper ConstraintTemplates are `templates.gatekeeper.sh/v1`; Constraints are `constraints.gatekeeper.sh/v1beta1` ([howto](https://open-policy-agent.github.io/gatekeeper/website/docs/howto), [library](https://open-policy-agent.github.io/gatekeeper-library/)).

## Decision

- Label every application namespace `pod-security.kubernetes.io/enforce=restricted` (and `audit`/`warn` the same). `kube-system` stays privileged.
- Install Gatekeeper from the official chart. Apply the library-based templates in [`policies/`](../policies/):
  - require container requests **and** limits (`K8sRequiredResources`)
  - require non-root (`K8sPSPAllowedUsers` `MustRunAsNonRoot`)
  - deny privileged (`K8sPSPPrivilegedContainer`)
  - HTTPS-only Ingress (`K8sHttpsOnly`) and HTTPS/TLS-only Gateway listeners (`K8sGatewayHttpsOnly`)
- Enforcement `deny` in CDE namespaces; start `dryrun` for one week on `platform` if a controller needs an exception.
- ValidatingAdmissionPolicy (CEL) for one-liners that do not deserve a ConstraintTemplate.
- Do **not** let Gatekeeper generate NetworkPolicy; Git owns those objects.

## Consequences

- Privileged debug Pods in CDE fail admission. Break-glass is a labeled exception namespace with MFA, not a cluster-wide off switch.
- Gatekeeper is a webhook: if it is down, fail-closed (`failurePolicy: Fail` on CDE). Platform controllers must have PDB + replicas.
- Kyverno would have been less Rego and more mutation. We lose generate/mutate convenience; we gain one policy language with Conftest in CI (`gator test`).

## Alternatives considered

- **Kyverno only.** Best on a greenfield YAML-native platform. Rejected because Rego is already the org language. Revisit if Kyverno 1.20 removes `ClusterPolicy` and the team wants CEL policies as code.
- **PSA only.** Free, insufficient for resource limits and TLS.
- **ValidatingAdmissionPolicy only.** No mutation, no audit of existing objects, CEL for everything. Use it *with* Gatekeeper, not instead.
- **Gatekeeper generate NetworkPolicy.** Fights Argo CD for object ownership. Git wins.
