# 0007. OpenTelemetry + Prometheus/Grafana + Loki + Tempo

- Status: Accepted
- Date: 2026-09-02

## Context

PCI-DSS 4.0.1 Req. 10 needs audit logs that outlive a container and cannot be edited by the workload. Operations need metrics, traces, and application logs to keep p99 authorization under 250 ms. Those are different streams. Mixing them (sending API audit to Loki, or PAN-bearing app logs to a shared Grafana) is how observability falls into the CDE.

The 2026 default vendor-neutral pipeline is OpenTelemetry for ingest, Prometheus for metrics, Grafana for UI, Loki for logs, Tempo for traces. kube-prometheus-stack **88.6.1** is the current prometheus-community chart. Loki’s OSS Helm chart moved to [grafana-community/helm-charts](https://github.com/grafana-community/helm-charts) on 16 March 2026 (forked at 6.55.0).

## Decision

- Deploy **OpenTelemetry Collector** (operator Helm chart from [open-telemetry-helm-charts](https://github.com/open-telemetry/opentelemetry-helm-charts)) as the only ingest: OTLP 4317/4318, Kubernetes attributes, **redaction processor** on known PAN/card fields.
- Deploy **kube-prometheus-stack 88.6.1** for Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics. Prometheus is the Argo Rollouts analysis backend ([ADR 0005](0005-argo-rollouts-progressive-delivery.md)).
- Deploy **Loki** (community chart) and **Tempo** with S3 backends. Operational retention 90 days.
- Keep **Kubernetes API audit logs in CloudWatch** (365 days) as the Req. 10 system of record. Do not treat Loki as the ROC audit trail.
- Hubble (Cilium) and Tetragon JSON go to the Collector, then Loki.

## Consequences

- One vendor-neutral wire protocol (OTLP). Apps do not speak Prometheus/Loki SDKs directly.
- If an app logs PAN, Loki/Tempo/Grafana become CDE. Redaction is a control, not a hope; Tetragon + code review are the backstop.
- Prometheus HA and Loki microservices mode cost real nodes; they run on the `platform` NodePool (Spot-eligible).
- CloudWatch audit log cost is accepted.

## Alternatives considered

- **Datadog / New Relic / Splunk as the only backend.** Faster day-1, another processor of potential CHD (contracts, DPA, scope). Rejected as the *sole* store; a dual-export is a later commercial decision.
- **Prometheus-only (no OTel).** Fine in 2020. Traces and logs then grow a second agent. Collector first.
- **ELK.** Heavier, more JVM, more nodes in PCI-adjacent scope.
- **Sending K8s audit to Loki only.** Loki is not the tamper-evident store we want for a ROC. CloudWatch/S3 is.
