# Control Tower Layer

> **Weeks 2-3** | **Purpose:** The "brain" that receives instructions, routes via Kafka, and orchestrates the 5 Agents

---

## Overview

The Control Tower is the central orchestration layer — the single "brain" that receives change requests from the Change Board, decides which Agent(s) to invoke, and coordinates execution across all environments.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTROL TOWER ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐         ┌──────────────────────────────┐             │
│   │ Change Board   │         │        Traefik Ingress       │             │
│   │ (Jira/ServiceNow│────────▶│    (Webhook Endpoint)        │             │
│   └─────────────────┘         └──────────────┬───────────────┘             │
│                                              │                              │
│                                              ▼                              │
│                                    ┌──────────────────────┐               │
│                                    │  Signature Validation │               │
│                                    │  (KMS + ECDSA)        │               │
│                                    └───────────┬──────────┘               │
│                                                │                            │
│                                                ▼                            │
│   ┌───────────────────────────────────────────────────────────────────┐    │
│   │                    STRIMZI KAFKA CLUSTER                          │    │
│   │  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────┐     │    │
│   │  │change-board│  │agent-instructions│  │ audit-events     │     │    │
│   │  │   topic    │──▶│     topic       │──▶│     topic        │     │    │
│   │  └─────────────┘  └─────────────────┘  └──────────────────┘     │    │
│   └───────────────────────────────────────────────────────────────────┘    │
│                                              │                              │
│                                              ▼                              │
│   ┌───────────────────────────────────────────────────────────────────┐    │
│   │               LANGCHAIN ORCHESTRATION LAYER                       │    │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │    │
│   │  │  Planner    │  │  Executor   │  │   Decision Engine       │ │    │
│   │  │  (decides)  │  │  (routes)   │  │   (AI-powered)          │ │    │
│   │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │    │
│   └───────────────────────────────────────────────────────────────────┘    │
│                                              │                              │
│         ┌─────────────────┬─────────────────┼─────────────────┐          │
│         ▼                 ▼                 ▼                 ▼          │
│   ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐        │
│   │ Security  │    │  Network  │    │   Infra   │    │  Apps     │        │
│   │  Agent    │    │  Agent    │    │  Agent    │    │  Agent    │        │
│   └───────────┘    └───────────┘    └───────────┘    └───────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **Compute** | EKS 1.31 (1-node spot, Karpenter-ready) | Kubernetes control plane |
| **Event Bus** | Strimzi Kafka (3-broker internal) | Message routing between components |
| **Serverless** | Knative Serving + Eventing | Auto-scaling Agent services |
| **Orchestration** | LangChain / Haystack | AI-powered decision making |
| **Infrastructure** | Crossplane core + AWS provider | Resource provisioning |
| **Ingress** | Traefik | Webhook endpoint management |

---

## Data Flow

### 1. Change Request Received
The Change Board (ServiceNow or Jira) sends a JSON payload to the webhook endpoint:

```json
{
  "request_id": "CR-2026-001",
  "type": "infrastructure",
  "action": "provision_namespace",
  "payload": {
    "environment": "sandbox",
    "namespace": "team-alpha",
    "quota": {
      "cpu": "10",
      "memory": "20Gi"
    }
  },
  "requester": "john.doe@company.com",
  "timestamp": "2026-02-15T10:30:00Z",
  "signature": "ECDSA-SHA256:..."
}
```

### 2. Webhook Validation (Week 9)
The Traefik webhook:
- Receives the request
- Validates ECDSA signature using KMS
- Rejects invalid requests immediately
- Publishes valid requests to Kafka

### 3. Kafka Topic: `change-board`
```json
{
  "topic": "change-board",
  "partition": 0,
  "key": "CR-2026-001",
  "value": {
    "request_id": "CR-2026-001",
    "validated": true,
    "timestamp": "2026-02-15T10:30:00Z"
  }
}
```

### 4. LangChain Planner
The LangChain planner:
- Consumes from `change-board` topic
- Analyzes the request
- Decides which Agent(s) to invoke
- Creates structured instructions

### 5. Kafka Topic: `agent-instructions`
```json
{
  "topic": "agent-instructions",
  "value": {
    "instruction_id": "INST-001",
    "target_agent": "infrastructure-agent",
    "action": "provision_namespace",
    "parameters": {
      "environment": "sandbox",
      "namespace": "team-alpha"
    },
    "priority": "normal",
    "deadline": "2026-02-15T11:30:00Z"
  }
}
```

### 6. Agent Execution
The target Agent (Knative service):
- Consumes instruction from `agent-instructions`
- Executes the requested action
- Publishes result to `audit-events`

### 7. Kafka Topic: `audit-events`
```json
{
  "topic": "audit-events",
  "value": {
    "event_id": "AUDIT-001",
    "instruction_id": "INST-001",
    "agent": "infrastructure-agent",
    "status": "success",
    "result": {
      "namespace": "team-alpha",
      "resources_created": ["namespace", "resourcequota", "limitrange"]
    },
    "duration_seconds": 45,
    "timestamp": "2026-02-15T10:31:00Z"
  }
}
```

---

## Kafka Topics

| Topic | Purpose | Producers | Consumers |
|-------|---------|-----------|-----------|
| `change-board` | Incoming change requests | Traefik webhook | LangChain Planner |
| `agent-instructions` | Structured instructions | LangChain Planner | All Agents |
| `audit-events` | Execution results | All Agents | Monitoring, Logging |
| `alerts` | Security alerts | Security Agent | On-call systems |
| `self-healing` | Resiliency events | Monitoring | Playbook Agent |

### Kafka Security Configuration
- **Authentication**: SASL/SCRAM
- **Authorization**: mTLS
- **Encryption**: TLS 1.3
- **Topics**: All use replication factor 3

---

## Knative Services

Each Agent runs as a Knative Serving service with auto-scaling:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: security-agent
  namespace: control-tower
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      serviceAccountName: security-agent-sa
      containers:
        - image: ghcr.io/openclaw/security-agent:latest
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
```

---

## Security Configuration

### Message Signing
- Keys stored in AWS KMS
- ECDSA signing for all messages
- Control Tower holds master key
- Each Agent has limited key access

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: control-tower-default
  namespace: control-tower
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: control-tower
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kafka
```

### Pod Security Standards
- Restricted PSP applied to all Agent pods
- No privileged containers
- Read-only root filesystem
- Drop all capabilities except required

---

## LangChain Orchestration

### Planner Component
```python
class AgentPlanner:
    def __init__(self, llm, tools):
        self.llm = llm
        self.tools = tools
    
    def plan(self, change_request: dict) -> list[AgentInstruction]:
        # Analyze request
        # Select appropriate Agent(s)
        # Generate structured instructions
        # Return priority-ordered list
```

### Decision Engine
The LangChain-powered decision engine:
1. **Intent Recognition** — What type of change is this?
2. **Agent Selection** — Which Agent(s) should handle it?
3. **Dependency Analysis** — What must happen first?
4. **Risk Assessment** — Is this change safe?
5. **Rollback Planning** — How do we undo if it fails?

---

## Deployment

### Prerequisites
- Foundation Layer complete
- EKS cluster provisioned
- Kafka operator installed

### Installation
```bash
# Install Strimzi Kafka
kubectl apply -k github.com/strimzi/strimzi-kafka-operator?ref=0.45.0

# Install Knative
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.0/serving-core.yaml

# Deploy Control Tower
kubectl apply -f control-tower/
```

---

## Verification

```bash
# Check Kafka pods
kubectl get pods -n kafka

# Check Knative services
kubectl get ksvc -n control-tower

# Verify Kafka topics
kubectl get kt -n kafka

# Test webhook endpoint
curl -X POST https://webhook.control-tower.io/health
```

---

## Next Steps

- [Monitoring Layer](/monitoring) — Deploy observability (Week 3)
- [Security Agent](/security-agent) — Deploy policy enforcement (Week 4)
- [Environments](/environments) — Provision isolated accounts (Weeks 7-8)
