# Monitoring Layer

> **Week 3** | **Purpose:** Read-only observability plane with zero write permissions — the only place humans ever view the estate

---

## Overview

The Monitoring Layer provides complete observability across all environments while maintaining strict **zero-write permissions** for human operators. This ensures that humans can observe but never modify the infrastructure.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MONITORING LAYER ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    CROSS-ACCOUNT DATA FLOW                          │  │
│   │                                                                     │  │
│   │  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐        │  │
│   │  │Sandbox  │    │   Dev   │    │  Test   │    │ Staging │        │  │
│   │  │   EKS   │    │   EKS   │    │   EKS   │    │   EKS   │        │  │
│   │  └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘        │  │
│   │       │              │              │              │              │  │
│   │       ▼              ▼              ▼              ▼              │  │
│   │  ┌─────────────────────────────────────────────────────────┐      │  │
│   │  │         OpenTelemetry Collector (Daemonset)             │      │  │
│   │  │         (Assumes Read-Only IRSA Role)                   │      │  │
│   │  └─────────────────────────┬───────────────────────────────┘      │  │
│   │                            │                                        │  │
│   │                            │ Remote Write                           │  │
│   │                            ▼                                        │  │
│   └────────────────────────────────────────────────────────────────────┘  │
│                                              │                            │
│                                              ▼                            │
│   ┌────────────────────────────────────────────────────────────────────┐  │
│   │                      MONITORING ACCOUNT                             │  │
│   │  ┌─────────────┐  ┌─────────────┐  ┌────────────────────────────┐ │  │
│   │  │ Prometheus  │  │    Loki     │  │          Tempo            │ │  │
│   │  │  + Thanos   │  │   (logs)    │  │        (traces)           │ │  │
│   │  └─────────────┘  └─────────────┘  └────────────────────────────┘ │  │
│   │                                                                     │  │
│   │  ┌─────────────────────────────────────────────────────────────┐  │  │
│   │  │                    Grafana 11                                │  │  │
│   │  │     (Pre-built Dashboards, Read-Only Access)               │  │  │
│   │  └─────────────────────────────────────────────────────────────┘  │  │
│   └────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **Metrics Collection** | OpenTelemetry Collector (daemonset) | Scrape and forward metrics |
| **Time Series DB** | Prometheus + Thanos | Long-term metric storage |
| **Log Aggregation** | Loki | Centralized logging |
| **Distributed Tracing** | Tempo | Request flow tracking |
| **Dashboards** | Grafana 11 | Visualization (read-only) |

---

## Data Flow

### Step 1: Telemetry Emission
Every pod in every environment automatically emits:
- **Metrics** via Prometheus scrape endpoint
- **Traces** via OpenTelemetry SDK
- **Logs** via stdout/stderr

### Step 2: Collection (Per Cluster)
OpenTelemetry Collector daemonset runs on each EKS cluster:
- Collects metrics/traces/logs from all pods
- Assumes **read-only** IRSA role
- No write permissions to production resources

```yaml
# OTel Collector Config
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_name]
              target_label: pod

exporters:
  otlp:
    endpoint: "tempo.monitoring.svc.cluster.local:4317"
  prometheus_remote_write:
    endpoint: "https://thanos.monitoring.svc:9090/api/v1/write"
  loki:
    endpoint: "http://loki.monitoring.svc:3100/loki/api/v1/push"
```

### Step 3: Cross-Account Shipping
The Collector uses IRSA to ship data to the Monitoring account:
- **Metrics** → Prometheus + Thanos (remote write)
- **Logs** → Loki (HTTP push)
- **Traces** → Tempo (OTLP)

### Step 4: Visualization
Grafana queries data under the same read-only role:
- No secrets stored in Monitoring account
- Humans can view but not modify
- Pre-built dashboards for each Agent and environment

---

## IRSA Permissions (Read-Only)

### Metrics Collection Role
```json
{
  "RoleName": "ControlTower-Monitoring-ReadOnly-Role",
  "AssumeRolePolicy": {
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::MONITORING_ACCOUNT:oidc-provider/..."
      },
      "Condition": {
        "StringEquals": {
          "oidc:sub": "system:serviceaccount:monitoring:otel-collector-sa"
        }
      }
    }]
  },
  "Policy": {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "eks:DescribeCluster",
        "eks:ListNodegroups",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }]
  }
}
```

### Grafana Role (Human Access)
```json
{
  "RoleName": "ControlTower-Monitoring-Viewer-Role",
  "AssumeRolePolicy": {
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MONITORING_ACCOUNT:root"
      },
      "Action": "sts:AssumeRole"
    }]
  },
  "Policy": {
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListNodegroups",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }]
  }
}
```

---

## Pre-Built Dashboards

### 1. Control Tower Overview
- Total clusters healthy
- Agent status (running/failed/scaling)
- Kafka topic lag
- Webhook request rate

### 2. Per-Agent Dashboards

| Agent | Dashboard Metrics |
|-------|-------------------|
| **Security Agent** | Kyverno policy violations, Falco alerts, GuardDuty findings |
| **Network Agent** | Cilium Hubble flows, Istio mTLS status, denied connections |
| **Infrastructure Agent** | Karpenter node launches, Crossplane resources, pod counts |
| **Applications Agent** | ArgoCD sync status, deployment frequency, Keptn results |
| **Member Agent** | Keycloak logins, new user requests, group memberships |

### 3. Environment Dashboards
- Pod count per namespace
- CPU/Memory utilization
- Network traffic (ingress/egress)
- Self-healing events

### 4. Security Dashboard
- Failed authentication attempts
- Policy rejection rate
- Network anomalies
- Audit event volume

---

## Alerting

### Alert Sources
- **Prometheus rules** — Metric-based alerts
- **Falco** — Runtime security events
- **Kyverno** — Policy violation events
- **Loki** — Log-based alerts

### Alert Routing
```
Alerts → Alertmanager → PagerDuty/OpsGenie → On-Call
                │
                └─→ Grafana (viewable by humans)
```

### Zero-Touch Principle
- **No human intervention** in alert response
- All alerts trigger Kafka events
- Agents automatically remediate
- Humans only **view** what happened

---

## Deployment

### Prerequisites
- Foundation Layer complete
- Monitoring AWS account provisioned

### Installation
```bash
# Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/release.Bundle.yaml

# Deploy collectors to each environment
kubectl apply -f monitoring/otel-collector/

# Install Thanos
helm install thanos monitoring/thanos

# Install Loki
helm install loki monitoring/loki

# Install Tempo
helm install tempo monitoring/tempo

# Install Grafana
helm install grafana grafana/grafana \
  --set admin.password=${GRAFANA_PASSWORD} \
  --set grafana.ini.auth.anonymous.enabled=true
```

---

## Verification

```bash
# Check OTel collectors
kubectl get pods -n monitoring -l app=otel-collector

# Verify metrics in Prometheus
kubectl exec -it prometheus-0 -n monitoring -- promtool check metrics

# Test Loki ingestion
curl -v "Content -H-Type: application/json" \
  -d '{"streams":[{"stream":{"job":"test"},"values":[["1667892296","test log"]]]}' \
  http://loki:3100/loki/api/v1/push

# Verify Grafana access
curl -u admin:${GRAFANA_PASSWORD} http://grafana.monitoring.svc/api/health
```

---

## Demo Script

1. **Show Live Dashboard** — Display Control Tower Overview with real-time metrics
2. **Show Agent Status** — Navigate to each Agent dashboard
3. **Simulate Alert** — Create a forbidden pod and watch auto-remediation
4. **Show Cross-Account** — Demonstrate that Monitoring has no write access to production

---

## Security Considerations

| Control | Implementation |
|---------|----------------|
| **No Write Access** | Humans can only READ from Monitoring account |
| **IRSA for Collection** | OTel collectors use temporary credentials |
| **Encrypted Transit** | All data encrypted in transit (TLS 1.3) |
| **Immutable Audit** | All logs shipped to S3 WORM storage |
| **Separate Account** | Monitoring in dedicated AWS account |

---

## Next Steps

- [Security Agent](/security-agent) — Deploy policy enforcement (Week 4)
- [Network Agent](/network-agent) — Deploy zero-trust networking (Week 4)
- [Playbooks](/playbooks) — Configure self-healing automations (Week 10)
