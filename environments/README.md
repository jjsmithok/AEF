# Environment Layers

> **Weeks 7-8** | **Purpose:** Provide exactly 5 strictly isolated AWS accounts with tailored policies

---

## Overview

The Control Tower operates across **5 isolated AWS accounts**, each with specific purposes and progressively stricter security policies. No cross-account traffic is allowed except via explicit Kafka-mediated instructions.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AWS ENVIRONMENT ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     AWS ORGANIZATION                                 │  │
│   │                                                                      │  │
│   │   ┌──────────────────────────────────────────────────────────────┐   │  │
│   │   │                    Root OU                                    │   │  │
│   │   │                                                                      │   │
│   │   │   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ │   │  │
│   │   │   │Sandbox  │ │   Dev   │ │  Test   │ │Staging  │ │  Prod   │ │   │  │
│   │   │   │ OU      │ │   OU    │ │   OU    │ │   OU    │ │   OU    │ │   │  │
│   │   │   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ │   │  │
│   │   │        │           │           │           │           │        │   │  │
│   │   │        ▼           ▼           ▼           ▼           ▼        │   │  │
│   │   │   ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐   │   │  │
│   │   │   │111111 │   │222222 │   │333333 │   │444444 │   │555555 │   │   │  │
│   │   │   │Sandbox│   │  Dev  │   │ Test  │   │Staging│   │ Prod  │   │   │  │
│   │   │   └───────┘   └───────┘   └───────┘   └───────┘   └───────┘   │   │  │
│   │   │                                                                      │   │
│   │   └──────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐   │  │
│   │   │                   Shared Services OU                           │   │  │
│   │   │   ┌─────────────┐  ┌─────────────┐  ┌────────────────────┐     │   │  │
│   │   │   │  Logging    │  │ Monitoring │  │    Security       │     │   │  │
│   │   │   │  (CloudTrail│  │ (Prometheus│  │   (GuardDuty,      │     │   │  │
│   │   │   │   + S3)     │  │   + Grafana)│  │    Inspector)     │     │   │  │
│   │   │   └─────────────┘  └─────────────┘  └────────────────────┘     │   │  │
│   │   └──────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│                         Control Tower (EKS + Kafka)                         │
│                                    │                                        │
│                            Cross-account IAM                                │
│                                    │                                        │
│            ┌───────────────────────┼───────────────────────┐               │
│            ▼                       ▼                       ▼               │
│      ┌─────────┐            ┌─────────┐            ┌─────────┐              │
│      │Sandbox  │            │  Test   │            │  Prod   │              │
│      │(dev)    │            │(verify) │            │(live)   │              │
│      └─────────┘            └─────────┘            └─────────┘              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Environment Specifications

| Environment | Account ID | Purpose | Node Count | Policy Strictness |
|-------------|------------|---------|------------|-------------------|
| **Sandbox** | 111111111111 | Development & testing | 3-10 (auto) | Lenient SCPs |
| **Dev** | 222222222222 | Agent development | 5-15 | Moderate restrictions |
| **Test** | 333333333333 | Integration testing | 10-20 | Strict policies |
| **Staging** | 444444444444 | Pre-production validation | 15-30 | Production-like |
| **Prod** | 555555555555 | Live operations | 20-50 | Deny-all except webhooks |

---

## Account Provisioning

### Via Crossplane
```yaml
apiVersion: aws.platform.openclaw.io/v1alpha1
kind: Account
metadata:
  name: sandbox
spec:
  accountId: "111111111111"
  email: "sandbox@control-tower.io"
  organizationalUnit: sandbox
```

### Via OpenTofu
```hcl
resource "aws_organizations_account" "sandbox" {
  name  = "sandbox"
  email = "sandbox@control-tower.io"
  
  parent_id = aws_organizations_organizational_unit.sandbox.id
}
```

---

## SCP Policies by Environment

### Sandbox (Lenient)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCommonActions",
    "Effect": "Allow",
    "Action": [
      "ec2:*",
      "eks:*",
      "s3:*",
      "rds:*"
    ],
    "Resource": "*"
  }]
}
```

### Test (Strict)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyProductionActions",
    "Effect": "Deny",
    "Action": [
      "aws:*",
      "organizations:*"
    ],
    "Resource": "*",
    "Condition": {
      "StringEquals": {
        "aws:RequestedRegion": ["us-east-1", "us-west-2"]
      }
    }
  }]
}
```

### Prod (Deny-All Except Approved)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyAllExceptWebhooks",
    "Effect": "Deny",
    "Action": ["*"],
    "Resource": "*",
    "Condition": {
      "StringNotEquals": {
        "aws:PrincipalTag/service-account": "control-tower-agent"
      }
    }
  }]
}
```

---

## Network Isolation

### No Direct Cross-Account Traffic
```
┌─────────────────────────────────────────────────────────────────┐
│                    ALLOWED TRAFFIC PATTERNS                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Sandbox ──▶ Dev ──▶ Test ──▶ Staging ──▶ Prod               │
│       │         │        │         │            │               │
│       │         │        │         │            │               │
│       ▼         ▼        ▼         ▼            ▼               │
│   ┌─────────────────────────────────────────────────────┐     │
│   │        ONLY via Kafka-mediated instructions         │     │
│   │        (Control Tower orchestrates all)             │     │
│   └─────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Transit Via Control Tower
1. **Sandbox** sends request to Control Tower
2. **Control Tower** validates and logs
3. **Control Tower** publishes to environment-specific Kafka topic
4. **Target environment** processes instruction
5. **Result** published to audit-events

---

## Shared Services

### Logging Account (666666666666)
- CloudTrail logs from all accounts
- S3 WORM storage (immutable)
- 7-year retention

### Monitoring Account (777777777777)
- Prometheus + Thanos
- Grafana dashboards
- Read-only access from all environments

### Security Account (888888888888)
- GuardDuty findings aggregation
- Inspector scans
- Security Hub central view

---

## Demo Script

1. **Show 5 Clusters** — Display all EKS clusters in Monitoring
2. **Show Different Node Counts** — Demonstrate auto-scaling
3. **Show Policy Enforcement** — Different SCPs in effect
4. **Attempt Cross-Account** — Show blocked traffic

---

## Next Steps

- [Governance Layer](/governance) — Configure HITL (Week 9)
- [Playbooks](/playbooks) — Configure self-healing (Week 10)
