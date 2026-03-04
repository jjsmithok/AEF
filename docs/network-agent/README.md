# Network Agent Layer

> **Week 4** | **Purpose:** Enforce zero-trust networking across all environments using Cilium and Istio

---

## Overview

The Network Agent implements zero-trust networking through a combination of **Cilium** (eBPF-based CNI) for network policies and **Istio** (service mesh) for mTLS and traffic management. All east-west and north-south traffic requires authentication.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    NETWORK AGENT ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    ZERO-TRUST NETWORK MODEL                         │  │
│   │                                                                     │  │
│   │   ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐  │  │
│   │   │ Service │ ───▶ │ Service │ ───▶ │ Service │ ───▶ │ Service │  │  │
│   │   │   A     │ mTLS  │   B     │ mTLS  │   C     │ mTLS  │   D     │  │  │
│   │   └─────────┘      └─────────┘      └─────────┘      └─────────┘  │  │
│   │       │                 │                 │                 │        │  │
│   │       ▼                 ▼                 ▼                 ▼        │  │
│   │   ┌───────────────────────────────────────────────────────────┐   │  │
│   │   │            Cilium Hubble (Network Visibility)              │   │  │
│   │   │     Flow logs, policy tracing, security observability      │   │  │
│   │   └───────────────────────────────────────────────────────────┘   │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    CONTROL PLANE                                    │  │
│   │                                                                     │  │
│   │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌─────────────┐  │  │
│   │  │ Network  │    │  Kafka   │    │ Cilium   │    │    Istio    │  │  │
│   │  │  Agent   │───▶│ Consumer │───▶│ Operator │───▶│   Control   │  │  │
│   │  │(LangChain│    │          │    │          │    │   Plane     │  │  │
│   │  └──────────┘    └──────────┘    └──────────┘    └─────────────┘  │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **CNI** | Cilium 1.16 (eBPF) | Network policies, pod networking |
| **Service Mesh** | Istio 1.23 | mTLS, traffic management |
| **Observability** | Hubble | Network flow visualization |
| **Policy Storage** | GitHub (ArgoCD) | NetworkPolicy CRDs |

---

## Cilium Network Policies

### Default Deny All
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector:
    matchLabels:
      app: anything
  egress:
    - toCIDRSet:
        - cidr: 0.0.0.0/0
          except:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
```

### Allow DNS Only
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns
spec:
  endpointSelector:
    matchLabels:
      app: my-app
  egress:
    - toEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": kube-system
            "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
```

### Allow Specific Service Communication
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

---

## Istio Authorization Policies

### Require mTLS
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-auth
  namespace: production
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/frontend-sa"]
      to:
        - operation:
            methods: ["GET", "POST"]
```

### Deny Unauthenticated
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}
  # Empty spec = deny all by default
```

### Allow External API
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-external-api
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  rules:
    - from:
        - source:
            notPrincipals: ["*"]
      to:
        - operation:
            paths: ["/health", "/ready"]
```

---

## Hubble Observability

### Enable Hubble
```yaml
# In Cilium ConfigMap
enable-hubble: "true"
hubble-tls-certificate: "/var/lib/cilium/tls/hubble.crt"
hubble-tls-key: "/var/lib/cilium/tls/hubble.key"
```

### View Network Flows
```bash
# CLI-based flow visualization
hubble observe --from-label "app=frontend" --to-label "app=backend"

# JSON output for automation
hubble observe --json | jq '.destINATION.name, .IP.protocol'
```

### Grafana Dashboard Integration
Hubble metrics exposed via Prometheus:
- `hubble_drop_total` — Dropped packets
- `hubble_flows_total` — Total flows processed
- `hubble_icmp_total` — ICMP traffic
- `hubble_dns_responses_total` — DNS queries

---

## Data Flow

### Policy Change Flow
```
GitHub PR (NetworkPolicy YAML) → ArgoCD Sync →
Network Agent watches Kafka → Validates policy →
Applies to Cilium/Istio → Hubble confirms enforcement
```

### Traffic Flow
```
Pod A initiates connection →
Cilium eBPF hook intercepts →
Check NetworkPolicy → Allow/Deny →
Istio mTLS handshake →
Traffic allowed/blocked →
Hubble logs flow
```

---

## Zero-Trust Principles

| Principle | Implementation |
|-----------|----------------|
| **Default Deny** | All traffic blocked unless explicitly allowed |
| **mTLS Everywhere** | All pod-to-pod communication encrypted |
| **Identity-Based** | Workload identity, not IP-based rules |
| **Egress Control** | Outbound traffic also filtered |
| **No Direct Pod Access** | All traffic through Istio sidecar |

---

## Network Architecture by Environment

| Environment | Policy Strictness | Egress Allowed |
|-------------|------------------|----------------|
| **Sandbox** | Moderate | Internet (limited) |
| **Dev** | Strict | Approved external APIs only |
| **Test** | Strict | Internal services |
| **Staging** | Production-like | Internal only |
| **Prod** | Deny-all | Explicit allowlist only |

---

## Deployment

### Prerequisites
- Kubernetes 1.29+
- Kernel headers for eBPF
- Control Tower deployed

### Installation
```bash
# Install Cilium
cilium install --version 1.16.0

# Enable Hubble
cilium hubble enable --ui

# Install Istio
istioctl install --set profile=default

# Deploy Network Agent
kubectl apply -f network-agent/
```

---

## Verification

```bash
# Check Cilium status
cilium status

# Verify Hubble connectivity
hubble status

# Test network policy
kubectl exec -it frontend-pod -- curl backend-svc:8080

# Verify mTLS
istioctl x authz check frontend-pod

# View Hubble flows
hubble observe --verdict DROPPED
```

---

## Demo Script

1. **Attempt Non-mTLS Connection** — Try plain HTTP between pods
2. **Show Hubble Block** — Visualize blocked connection in Hubble UI
3. **Apply Policy** — Deploy allow policy via ArgoCD
4. **Show mTLS** — Verify mutual TLS in connection

---

## Integration with Other Agents

| Agent | Interaction |
|-------|-------------|
| **Security Agent** | Receives network anomaly alerts via Kafka |
| **Infrastructure Agent** | Creates VPCs, subnets used by Cilium |
| **Applications Agent** | Uses Istio for traffic splitting |
| **Monitoring** | Hubble metrics to Grafana |

---

## Next Steps

- [Infrastructure Agent](/infrastructure-agent) — Deploy compute provisioning (Week 5)
- [Applications Agent](/applications-agent) — Deploy GitOps (Week 6)
- [Environments](/environments) — Create isolated accounts (Weeks 7-8)
