# Applications Agent Layer

> **Week 6** | **Purpose:** GitOps-driven application lifecycle and progressive delivery

---

## Overview

The Applications Agent manages application deployment through ArgoCD for GitOps and Keptn for quality gates. It handles the complete lifecycle from code push to production.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                  APPLICATIONS AGENT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    DEPLOYMENT PIPELINE                               │  │
│   │                                                                     │  │
│   │   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐        │  │
│   │   │  Git   │───▶│ ECR /   │───▶│ ArgoCD  │───▶│  Keptn  │        │  │
│   │   │  Push  │    │ Registry│    │  Sync   │    │ Quality │        │  │
│   │   └─────────┘    └─────────┘    └─────────┘    └────┬────┘        │  │
│   │                                                       │             │  │
│   │   ┌───────────────────────────────────────────────────┘             │  │
│   │   │                                                               │  │
│   │   ▼                                                               ▼       │  │
│   │   Sandbox ──▶ Dev ──▶ Test ──▶ Staging ──▶ Prod                  │  │
│   │   (auto)      (auto)    (auto)      (manual)     (approved)       │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    CONTROL FLOW                                      │  │
│   │                                                                     │  │
│   │   GitHub Actions ──▶ Kafka ──▶ Apps Agent ──▶ ArgoCD ApplicationSet│  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **GitOps** | ArgoCD 2.12+ | Declarative deployments |
| **Progressive Delivery** | Keptn 2.x | Quality gates & canary |
| **Registry** | ECR | Container image storage |
| **Orchestration** | LangChain | Deployment decisions |

---

## ArgoCD ApplicationSet

### Multi-Environment Template
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
spec:
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/openclaw/apps.git
              revision: HEAD
              directories:
                - path: apps/*
          - clusters:
              selector:
                matchLabels:
                  environment: "*"
  template:
    metadata:
      name: '{{path.basename}}-{{metadata.labels.environment}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/openclaw/apps.git
        targetRevision: HEAD
        path: '{{path.basename}}/overlays/{{metadata.labels.environment}}'
      destination:
        server: '{{server}}'
        namespace: '{{metadata.labels.environment}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Environment-Specific Overlay
```yaml
# apps/myapp/overlays/sandbox/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: myapp
      spec:
        replicas: 1
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
```

---

## Keptn Quality Gates

### Evaluation Task
```yaml
apiVersion: keptn.sh/v1alpha1
kind: Evaluation
metadata:
  name: deployment-quality-gate
spec:
  analysisDefinition:
    name: evaluation-definition
  retries: 3
  retryInterval: 5s
  timeout: 5m
```

### Analysis Definition
```yaml
apiVersion: keptn.sh/v1alpha1
kind: AnalysisDefinition
metadata:
  name: evaluation-definition
spec:
  objectives:
    - objective:
        analysisQuery: slo-query-1
        weight: 1
        keySLO: response_time_p95
    - objective:
        analysisQuery: slo-query-2
        weight: 1
        keySLO: error_rate
    - objective:
        analysisQuery: slo-query-3
        weight: 1
        keySLO: availability
```

---

## Progressive Delivery

### Canary Deployment
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-rollout
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: myapp-canary
      stableService: myapp-stable
      trafficRouting:
        istio:
          virtualService:
            name: myapp-vsvc
            routes:
              - primary
      steps:
        - setWeight: 10
        - pause: {duration: 10m}
        - setWeight: 30
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {duration: 10m}
        - setWeight: 100
```

### Auto-Promotion Rules
```yaml
apiVersion: keptn.sh/v1alpha1
kind: Evaluation
metadata:
  name: promotion-evaluation
spec:
  evaluationDefinition: quality-gate
  passCriteria:
    - evaluationTarget: ">=90"
      keySLO: "score"
```

---

## Kafka Integration

### Instruction Format
```json
{
  "topic": "agent-instructions",
  "value": {
    "instruction_id": "INST-003",
    "target_agent": "applications-agent",
    "action": "promote_image",
    "parameters": {
      "application": "payment-service",
      "source_env": "staging",
      "target_env": "production",
      "image_tag": "v2.5.1",
      "quality_gates_passed": true
    }
  }
}
```

### Execution Flow
```python
class ApplicationsAgent:
    def promote_image(self, params):
        # 1. Verify quality gates passed
        if not self.verify_quality_gates(params):
            raise Exception("Quality gates failed")
        
        # 2. Update image tag in Git
        self.update_git_tag(
            params.application,
            params.target_env,
            params.image_tag
        )
        
        # 3. ArgoCD syncs automatically
        # 4. Monitor rollout progress
        # 5. Publish audit event
        
        return {
            "status": "promoted",
            "environment": params.target_env,
            "image": params.image_tag
        }
```

---

## Deployment

### Prerequisites
- Infrastructure Agent deployed
- ECR repositories created
- Istio installed

### Installation
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Keptn
helm install keptn keptn/keptn -n keptn-system --create-namespace

# Deploy Applications Agent
kubectl apply -f applications-agent/
```

---

## Verification

```bash
# Check ArgoCD applications
argocd app list

# Check rollouts
kubectl get rollouts

# Check Keptn evaluations
kubectl get evaluations -n keptn

# Verify sync
arg myapp
```

ocd app sync---

## Demo Script

1. **Tag Promotion** — Show Git tag pushed
2. **Full Pipeline** — Display ArgoCD sync to Sandbox → Dev → Test → Staging
3. **Quality Gates** — Show Keptn evaluation results
4. **Production Deploy** — Approve and watch rollout

---

## GitOps Repository Structure

```
/
├── apps/
│   ├── service-a/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── sandbox/
│   │       ├── dev/
│   │       ├── test/
│   │       ├── staging/
│   │       └── production/
│   └── service-b/
│       └── ...
├── environments/
│   └── (cluster configs)
└── system/
    └── (ArgoCD ApplicationSets)
```

---

## Next Steps

- [Member Agent](/member-agent) — Deploy identity management (Week 6)
- [Environments](/environments) — Create isolated accounts (Weeks 7-8)
- [Playbooks](/playbooks) — Configure self-healing (Week 10)
