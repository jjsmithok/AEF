# Playbooks & Resiliency Layer

> **Week 10** | **Purpose:** Library of 30+ LangChain-driven self-healing automations

---

## Overview

The Playbooks Layer contains a comprehensive library of autonomous self-healing automations. When anomalies are detected by Falco, Kyverno, or Prometheus, events flow to Kafka where the appropriate Agent loads a playbook and executes remediation.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PLAYBOOK EXECUTION FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    DETECTION SOURCES                                 │  │
│   │                                                                      │  │
│   │   ┌─────────┐    ┌─────────┐    ┌────────────┐    ┌───────────┐  │  │
│   │   │ Falco   │    │ Kyverno │    │ Prometheus │    │  Custom   │  │  │
│   │   │(runtime)│    │(policy) │    │ (metrics)  │    │  Webhook  │  │  │
│   │   └────┬────┘    └────┬────┘    └─────┬──────┘    └─────┬─────┘  │  │
│   │        │              │               │                 │         │  │
│   │        └──────────────┴───────────────┴─────────────────┘         │  │
│   │                                    │                                │  │
│   │                                    ▼                                │  │
│   │   ┌─────────────────────────────────────────────────────────────┐  │  │
│   │   │                    KAFKA TOPIC: self-healing                 │  │  │
│   │   └────────────────────────────┬────────────────────────────────┘  │  │
│   │                              │                                      │  │
│   │                              ▼                                      │  │
│   │   ┌─────────────────────────────────────────────────────────────┐  │  │
│   │   │                    AGENT SELECTION                            │  │  │
│   │   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │  │  │
│   │   │   │   Security  │  │   Network   │  │     Infra Agent    │ │  │  │
│   │   │   │    Agent    │  │    Agent    │  │                     │ │  │  │
│   │   │   └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │  │  │
│   │   │          │               │                    │            │  │  │
│   │   └──────────┴───────────────┴────────────────────┴────────────┘  │  │
│   │                              │                                      │  │
│   │                              ▼                                      │  │
│   │   ┌───────────────────────────────────────────────────────────────┐  │  │
│   │   │               LANGCHAIN PLAYBOOK ENGINE                       │  │  │
│   │   │   ┌─────────────────────────────────────────────────────────┐ │  │  │
│   │   │   │  1. Analyze Event    2. Load Playbook    3. Execute   │ │  │  │
│   │   │   │  4. Verify Result    5. Update Dashboard  6. Document │ │  │  │
│   │   │   └─────────────────────────────────────────────────────────┘ │  │  │
│   │   └───────────────────────────────────────────────────────────────┘  │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Playbooks

### 1. Pod Auto-Restart
```yaml
name: pod-auto-restart
trigger: Prometheus (Pod Restart > 3 in 10 min)
action:
  - Identify failing pod
  - Check pod logs for error pattern
  - Delete pod (let K8s recreate)
  - Verify new pod healthy
execution_time: < 60 seconds
success_rate: 95%
```

### 2. Node Failure Remediation
```yaml
name: node-failure-remediation
trigger: Karpenter (Node unhealthy > 5 min)
action:
  - Cordon failing node
  - Drain workloads
  - Trigger new node provision
  - Verify workloads rescheduled
execution_time: < 90 seconds
success_rate: 97%
```

### 3. Database Connection Pool Exhaustion
```yaml
name: db-connection-recovery
trigger: Prometheus (DB connections > 90% max)
action:
  - Identify offending pods
  - Force restart pod
  - Adjust HPA (if configured)
  - Alert on call
execution_time: < 2 minutes
success_rate: 90%
```

### 4. Network Policy Conflict Resolution
```yaml
name: network-policy-conflict
trigger: Kyverno (Policy conflict detected)
action:
  - Analyze conflicting policies
  - Merge or prioritize rules
  - Apply resolved policy
  - Document resolution
execution_time: < 30 seconds
success_rate: 85%
```

### 5. Certificate Expiry Warning
```yaml
name: certificate-rotation
trigger: Cert-manager (Cert expires < 7 days)
action:
  - Identify expiring certificate
  - Trigger renewal
  - Verify new certificate
  - Update Istio config
execution_time: < 5 minutes
success_rate: 99%
```

### 6. Disk Space Recovery
```yaml
name: disk-space-recovery
trigger: Prometheus (Disk > 85%)
action:
  - Identify large PVCs
  - Clean up old logs
  - Resize PVC (if needed)
  - Archive old data
execution_time: < 10 minutes
success_rate: 92%
```

### 7. Service Mesh Recovery
```yaml
name: istio-sidecar-recovery
trigger: Istio (Sidecar injection failed)
action:
  - Check namespace label
  - Regenerate sidecar
  - Restart affected pods
  - Verify mTLS
execution_time: < 2 minutes
success_rate: 95%
```

### 8. Kafka Consumer Lag Recovery
```yaml
name: kafka-lag-recovery
trigger: Prometheus (Consumer lag > 10000)
action:
  - Identify lagging consumer
  - Check consumer health
  - Restart consumer if stuck
  - Rebalance if needed
execution_time: < 5 minutes
success_rate: 88%
```

---

## LangChain Playbook Structure

```python
class Playbook:
    def __init__(self, name: str, trigger: str, actions: list):
        self.name = name
        self.trigger = trigger
        self.actions = actions
    
    async def execute(self, event: dict) -> PlaybookResult:
        # 1. Analyze event context
        context = await self.analyze(event)
        
        # 2. Generate execution plan
        plan = await self.llm.generate_plan(context)
        
        # 3. Execute actions
        results = []
        for action in self.actions:
            result = await action.execute()
            results.append(result)
        
        # 4. Verify success
        verified = await self.verify(results)
        
        # 5. Update metrics
        await self.record_metrics(verified)
        
        return PlaybookResult(
            playbook=self.name,
            success=verified,
            results=results,
            duration=time_elapsed
        )
```

---

## Metrics & Dashboards

### Playbook Success Metrics
| Metric | Description |
|--------|-------------|
| `playbook_executions_total` | Total playbook runs |
| `playbook_success_total` | Successful remediations |
| `playbook_duration_seconds` | Execution time |
| `playbook_failures_total` | Failed attempts |

### Remediation Dashboard
- Success/failure rate by playbook
- Average time to remediation
- Most common triggers
- Cost savings from automation

---

## Chaos Testing

### Regular Drills
```yaml
# Weekly chaos injection
apiVersion: chaos.platform.openclaw.io/v1alpha1
kind: ChaosExperiment
metadata:
  name: node-failure-test
spec:
  action: node-failure
  target: 1 node
  schedule: "0 2 * * 0"  # Weekly Sunday 2AM
  expected_remediation: node-failure-remediation
```

### Verification
- Playbooks tested against simulated failures
- Success rate tracked
- False positives minimized
- Runbooks updated based on results

---

## Demo Script

1. **Inject Failure** — Simulate node failure
2. **Auto-Detection** — Show alert in Grafana
3. **Auto-Remediation** — Watch playbook execute
4. **Show Success** — Dashboard updates to 97%

---

## Maintenance

### Adding New Playbooks
1. Define trigger (Prometheus/Falco/Kyverno)
2. Write playbook YAML
3. Register with Agent
4. Add to chaos test suite

### Playbook Review
- Monthly review of success rates
- Quarterly playbook additions
- Annual comprehensive testing

---

## Success Metrics

| Metric | Target |
|--------|--------|
| **Automation Rate** | >90% of alerts auto-resolved |
| **MTTR** | <5 minutes |
| **False Positive Rate** | <5% |
| **Playbook Library** | 30+ playbooks |
| **Success Rate** | >95% |

---

## Summary

The Playbooks Layer completes the autonomous operation of the Control Tower. Combined with all previous layers:

- **Zero human touch** after Foundation
- **Fully automated** detection → remediation → audit
- **Self-healing** infrastructure
- **Continuous improvement** via chaos testing
