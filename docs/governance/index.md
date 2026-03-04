# Governance Layer (HITL)

> **Week 9** | **Purpose:** The only human touchpoint — external Change Board integration with full audit

---

## Overview

The Governance Layer provides the **only human interaction point** with the Control Tower. All changes flow through a secure webhook with signature validation, and break-glass access is strictly controlled via Teleport.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GOVERNANCE LAYER ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    HUMAN TOUCHPOINT FLOW                             │  │
│   │                                                                      │  │
│   │   ┌─────────┐    ┌──────────────┐    ┌─────────────────────────┐   │  │
│   │   │ Service │───▶│   Traefik    │───▶│  Signature Validation   │   │  │
│   │   │Now/Jira │    │   Webhook    │    │  (KMS + ECDSA)         │   │  │
│   │   └─────────┘    └──────────────┘    └───────────┬─────────────┘   │  │
│   │                                                      │               │  │
│   │                                                      ▼               │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                    CONTROL TOWER                            │   │  │
│   │   │   Kafka → LangChain → Agents → Audit → WORM Storage         │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    BREAK-GLASS ACCESS                               │  │
│   │                                                                      │  │
│   │   ┌─────────┐    ┌──────────────┐    ┌─────────────────────────┐   │  │
│   │   │  Human  │───▶│   Teleport   │───▶│  4-Eye Principle        │   │  │
│   │   │ (admin) │    │   (SSH/DB)   │    │  + Session Recording    │   │  │
│   │   └─────────┘    └──────────────┘    └─────────────────────────┘   │  │
│   │                                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **Webhook** | Traefik + mTLS + AWS SigV4 | Secure change intake |
| **Break-Glass** | Teleport | Audited emergency access |
| **Approval** | External Change Board | Human authorization |
| **Audit** | S3 WORM | Immutable event storage |

---

## Webhook Configuration

### Traefik IngressRoute
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: webhook
  namespace: control-tower
spec:
  entryPoints:
    - websecure
  tls:
    certResolver: aws
  routes:
    - match: PathPrefix(`/webhook`)
      kind: Rule
      services:
        - name: webhook-validator
          port: 8080
```

### Signature Validation
```python
def validate_signature(payload: dict, signature: str) -> bool:
    # Get public key from KMS
    public_key = kms_client.get_public_key(KeyId='webhook-signing-key')
    
    # Verify ECDSA signature
    verifier = ecdsa.Verifier(public_key)
    return verifier.verify(payload, signature)
```

---

## Change Board Integration

### Jira Webhook Payload
```json
{
  "issue": {
    "key": "CT-1234",
    "fields": {
      "summary": "Provision new team namespace",
      "description": "Create namespace team-beta in sandbox",
      "issuetype": {"name": "Task"},
      "customfield_10012": "team-beta",
      "customfield_10013": "sandbox"
    }
  },
  "user": {
    "accountId": "abc123",
    "email": "admin@company.com"
  },
  "timestamp": "2026-02-15T10:30:00Z"
}
```

### Approval Workflow
```
1. User creates Jira ticket
2. Change Board reviews (human)
3. Approved → Webhook receives payload
4. Rejected → No action, ticket closed
5. Executed → Result posted back to Jira
```

---

## Break-Glass Access

### Teleport Configuration
```yaml
auth_service:
  enabled: true
  listeners:
    - addr: 0.0.0.0:3025
  cluster_name: control-tower

proxy_service:
  enabled: true
  listen_addr: 0.0.0.0:3080

ssh_service:
  enabled: true
  labels:
    env: production

db_service:
  enabled: true
  databases:
    - name: prod-db
      protocol: postgres
```

### 4-Eye Principle
```yaml
apiVersion: teleport.acme.com/v1
kind: AccessRequest
metadata:
  name: emergency-fix
spec:
  user: admin@company.com
  resource: eks/prod/namespace critical
  duration: 30m
  approvers:
    - sec-lead@company.com
    - platform-lead@company.com
  audit: true
```

### Session Recording
- All SSH sessions recorded
- All kubectl commands logged
- Stored in S3 WORM for 7 years
- Playback available for incidents

---

## Audit Trail

### WORM Storage Configuration
```hcl
resource "aws_s3_bucket" "audit_logs" {
  bucket = "control-tower-audit-logs"
  
  versioning {
    enabled = true
  }
  
  object_lock_enabled = true
  
  lifecycle_rule {
    id     = "immutable"
    enabled = true
    
    expiration {
      days = 2555  # 7 years
    }
  }
}
```

### Audit Event Schema
```json
{
  "event_id": "AUDIT-001",
  "timestamp": "2026-02-15T10:30:00Z",
  "type": "change_request",
  "actor": {
    "type": "service_account",
    "id": "webhook-validator"
  },
  "request": {
    "source": "jira",
    "ticket_id": "CT-1234",
    "action": "provision_namespace"
  },
  "decision": {
    "approved_by": "change-board",
    "approved_at": "2026-02-15T10:29:00Z"
  },
  "execution": {
    "agent": "infrastructure-agent",
    "result": "success",
    "duration_ms": 45000
  }
}
```

---

## Zero-Touch Guarantee

| Control | Implementation |
|---------|----------------|
| **No Direct Access** | Humans cannot access EKS clusters directly |
| **Webhooks Only** | All changes via validated webhooks |
| **Break-Glass Audited** | Every emergency access recorded |
| **4-Eye Principle** | Two approvers required for emergency access |
| **Immutable Audit** | S3 WORM prevents deletion |

---

## Demo Script

1. **Submit Jira Ticket** — Create change request
2. **Show Approval** — Approve in Change Board
3. **Watch Execution** — End-to-end flow visible
4. **Show Audit** — Immutable log in S3

---

## Next Steps

- [Playbooks](/playbooks) — Configure self-healing (Week 10)
