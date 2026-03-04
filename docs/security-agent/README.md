# Security Agent Layer

> **Week 4** | **Purpose:** Continuous policy enforcement and autonomous threat remediation

---

## Overview

The Security Agent provides automated policy enforcement and real-time threat detection. It uses Kyverno for policy-as-code and Falco for runtime security monitoring, with LangChain-powered remediation playbooks.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SECURITY AGENT ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    EVENT PROCESSING PIPELINE                        │  │
│   │                                                                     │  │
│   │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐ │  │
│   │  │ Kyverno  │    │  Falco   │    │  Kafka   │    │  Security    │ │  │
│   │  │ Webhook  │───▶│  Events  │───▶│  Events  │───▶│    Agent     │ │  │
│   │  │(policy)  │    │ (runtime)│    │  Topic   │    │ (LangChain)  │ │  │
│   │  └──────────┘    └──────────┘    └──────────┘    └──────┬───────┘ │  │
│   │                                                        │          │  │
│   │                                                        ▼          │  │
│   │  ┌─────────────────────────────────────────────────────────────┐  │  │
│   │  │                    REMEDIATION ACTIONS                      │  │  │
│   │  │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────┐  │  │  │
│   │  │   │ Mutate  │  │  Evict  │  │ Quarant│  │  Alert      │  │  │  │
│   │  │   │Resource │  │   Pod   │  │  Host  │  │  Security   │  │  │  │
│   │  │   └─────────┘  └─────────┘  └─────────┘  └─────────────┘  │  │  │
│   │  └─────────────────────────────────────────────────────────────┘  │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **Policy Engine** | Kyverno | Kubernetes policy enforcement |
| **Runtime Detection** | Falco | Anomalous syscall detection |
| **Automation** | 5 Initial LangChain Playbooks | Autonomous remediation |
| **Integration** | Kafka + Knative | Event-driven execution |

---

## Kyverno Policies

### 1. Require Specific Labels
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-for-label
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Label 'environment' is required"
        pattern:
          metadata:
            labels:
              environment: "?*"
```

### 2. Restrict Image Registries
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: allowed-registries
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Only approved registries allowed"
        pattern:
          spec:
            containers:
              - image: "regex:(^ghcr.io/|^public.ecr.aws/)"
```

### 3. Disallow Privileged Containers
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  rules:
    - name: no-privileged
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Privileged containers are not allowed"
        deny:
          conditions:
            - key: "{{ request.object.spec.containers[?securityContext.privileged == true] }}"
              operator: NotEqual
              value: []
```

### 4. Require Network Policies
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-network-policy
spec:
  validationFailureAction: Audit
  rules:
    - name: check-network-policy
      match:
        resources:
          kinds:
            - Namespace
      preconditions:
        - key: "{{ request.object.metadata.labels.network-policy }}"
          operator: Equal
          value: "required"
      validate:
        message: "Namespace must have a NetworkPolicy"
        deny:
          conditions:
            - key: "{{ request.object.metadata.name }}"
              operator: NotEqual
              value: ""
```

---

## Falco Rules

### 1. Detect Shell in Container
```yaml
- rule: Shell in container
  desc: Detect shell execution in container
  condition: >
    container.id != host and
    proc.name in (bash, sh, dash, zsh)
  output: "Shell detected in container (user=%user.name container=%container.id proc=%proc.name)"
  priority: Warning
```

### 2. Detect Unauthorized Process
```yaml
- rule: Unauthorized process
  desc: Detect process not in allowed list
  condition: >
    not proc.name in (allowed_processes)
  output: "Unauthorized process (container=%container.id proc=%proc.name)"
  priority: Critical
```

### 3. Detect Sensitive File Access
```yaml
- rule: Sensitive file access
  desc: Detect access to sensitive files
  condition: >
    fd.name in (sensitive_files) or
    fd.name startswith /etc/shadow
  output: "Sensitive file access (file=%fd.name user=%user.name)"
  priority: Critical
```

### 4. Detect Network Anomaly
```yaml
- rule: Unexpected network connection
  desc: Detect unexpected outbound connections
  condition: >
    evt.type = connect and
    not fd.sip in (allowed_ips)
  output: "Unexpected network connection (fd=%fd.name cip=%fd.cip)"
  priority: Warning
```

---

## Remediation Playbooks

### Playbook 1: Auto-Patch Forbidden Pod
```yaml
name: auto-patch-pod
trigger: Kyverno policy violation (non-privileged)
action: Mutate resource to remove privileged flag
execution_time: < 5 seconds
verification: Re-validate against policy
```

### Playbook 2: Evict Malicious Container
```yaml
name: evict-malicious-container
trigger: Falco critical alert (shell in container)
action: 
  1. Capture container state
  2. Evict pod
  3. Block image in registry
  4. Notify via Kafka
execution_time: < 30 seconds
verification: Pod no longer running
```

### Playbook 3: Quarantine Compromised Node
```yaml
name: quarantine-node
trigger: Falco alert (sensitive file access)
action:
  1. Cordon node
  2. Drain workloads
  3. Tag for investigation
  4. Notify security team
execution_time: < 60 seconds
verification: Node cordoned, no new pods scheduled
```

### Playbook 4: Rollback Deployment
```yaml
name: rollback-deployment
trigger: Kyverno policy violation (deployment)
action:
  1. Identify previous healthy revision
  2. Scale to zero violating pods
  3. Scale up previous revision
execution_time: < 2 minutes
verification: Previous revision running
```

### Playbook 5: Generate Security Report
```yaml
name: security-report
trigger: Daily cron
action:
  1. Aggregate all events from Kafka
  2. Generate markdown report
  3. Publish to S3
  4. Send summary to Slack
execution_time: < 5 minutes
verification: Report accessible in S3
```

---

## Data Flow

### Kyverno Flow
```
User creates Pod → Kyverno webhook intercepts → 
Policy check → Pass: allow | Fail: mutate/deny →
Event published to Kafka → Security Agent logs
```

### Falco Flow
```
Container runs → Falco monitors syscalls →
Anomaly detected → Event to userspace →
Kafka event → Security Agent evaluates →
Remediation action taken → Audit to monitoring
```

---

## Integration with Control Tower

```json
{
  "topic": "security-events",
  "producer": "falco/kyverno",
  "consumer": "security-agent",
  "sample_event": {
    "event_id": "SEC-001",
    "source": "kyverno",
    "type": "policy_violation",
    "severity": "high",
    "resource": {
      "kind": "Pod",
      "name": "malicious-pod",
      "namespace": "default"
    },
    "policy": "disallow-privileged",
    "action": "deny",
    "timestamp": "2026-02-15T10:30:00Z"
  }
}
```

---

## Deployment

### Prerequisites
- Control Tower Layer deployed
- Knative installed
- Kafka topics available

### Installation
```bash
# Install Kyverno
kubectl create -f https://kyverno.io/install.yaml

# Install Falco
helm install falco falco/falco \
  --set falco.jsonOutput=true \
  --set falco.kafkaBrokers="kafka.kafka.svc:9092" \
  --set falco.kafkaTopic="security-events"

# Deploy Security Agent
kubectl apply -f security-agent/
```

---

## Verification

```bash
# Check Kyverno policies
kubectl get cpol

# Check Falco running
kubectl get pods -n falco

# Test policy enforcement
kubectl run privileged --image=nginx --privileged=true

# Verify event in Kafka
kubectl -n kafka consume --from-beginning --max-messages=1 security-events
```

---

## Demo Script

1. **Create Forbidden Pod** — Attempt to deploy privileged container
2. **Auto-Patch in <30s** — Watch Kyverno deny and patch
3. **Alert in Monitoring** — Show Grafana dashboard with event
4. **Show Kafka Event** — Display event payload in Kafka

---

## Initial Policy Set

| Category | Policies |
|----------|----------|
| **Pod Security** | 5 policies (privileged, capabilities, hostPID, hostIPC, hostNetwork) |
| **Network** | 3 policies (require network policy, restrict egress, allowlist) |
| **Images** | 4 policies (registry allowlist, tag latest banned, no root) |
| **RBAC** | 3 policies (no cluster admin, require subjects, restrict bindings) |
| **Secrets** | 2 policies (no secrets in env, require secret encryption) |

---

## Next Steps

- [Network Agent](/network-agent) — Deploy zero-trust networking (Week 4)
- [Governance Layer](/governance) — Configure HITL (Week 9)
- [Playbooks](/playbooks) — Expand automation library (Week 10)
