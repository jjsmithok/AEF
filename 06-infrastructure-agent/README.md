# Infrastructure Agent Layer

> **Week 5** | **Purpose:** Autonomous provisioning and scaling of compute, storage, and networking

---

## Overview

The Infrastructure Agent uses Crossplane for infrastructure-as-code and Karpenter for auto-scaling compute. It watches Kafka for provisioning requests and automatically creates AWS resources.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 INFRASTRUCTURE AGENT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    PROVISIONING FLOW                                 │  │
│   │                                                                     │  │
│   │   Git Commit ──▶ ArgoCD Sync ──▶ Kafka (instruction) ──▶            │  │
│   │                                                             │         │  │
│   │   ┌──────────────────────────────────────────────────────────┐      │  │
│   │   │              Infrastructure Agent (Knative)               │      │  │
│   │   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │      │  │
│   │   │   │   Analyzer  │  │  Executor   │  │  Verifier       │  │      │  │
│   │   │   │ (LangChain) │  │ (Crossplane)│  │ (Health Check)  │  │      │  │
│   │   │   └─────────────┘  └─────────────┘  └─────────────────┘  │      │  │
│   │   └──────────────────────────────────────────────────────────┘      │  │
│   │                              │                                       │  │
│   │                              ▼                                       │  │
│   │   ┌──────────────────────────────────────────────────────────┐      │  │
│   │   │              AWS RESOURCES (via Crossplane)              │      │  │
│   │   │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐  │      │  │
│   │   │   │   EKS   │  │  Karpenter│  │    S3   │  │   RDS    │  │      │  │
│   │   │   │ Cluster │  │  NodePool │  │ Buckets │  │ Databases│  │      │  │
│   │   │   └─────────┘  └─────────┘  └─────────┘  └──────────┘  │      │  │
│   │   └──────────────────────────────────────────────────────────┘      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **IaC Engine** | Crossplane Compositions | Declarative infrastructure |
| **Node Scaling** | Karpenter 1.0 | Spot/ondemand compute |
| **Cluster API** | Cluster-API | EKS cluster lifecycle |
| **Orchestration** | LangChain | Intelligent provisioning |

---

## Crossplane Compositions

### EKS Cluster Composition
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xeksclusters.aws.platform.openclaw.io
spec:
  resources:
    - name: cluster
      base:
        apiVersion: aws.platform.openclaw.io/v1alpha1
        kind: EKSCluster
        spec:
          region: us-east-1
          version: "1.31"
          roleArn: arn:aws:iam::*:role/ControlTower-InfraAgent-Role
      patches:
        - fromFieldPath: metadata.name
          toFieldPath: metadata.name
        - fromFieldPath: spec.forProvider.version
          toFieldPath: spec.forProvider.version
```

### RDS Database Composition
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xrdsinstances.aws.platform.openclaw.io
spec:
  resources:
    - name: database
      base:
        apiVersion: aws.platform.openclaw.io/v1alpha1
        kind: RDSInstance
        spec:
          region: us-east-1
          dbInstanceClass: db.t3.micro
          engine: postgres
          engineVersion: "15.4"
          allocatedStorage: 20
```

### S3 Bucket Composition
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xbuckets.aws.platform.openclaw.io
spec:
  resources:
    - name: bucket
      base:
        apiVersion: aws.platform.openclaw.io/v1alpha1
        kind: S3Bucket
        spec:
          region: us-east-1
          versioningEnabled: true
```

---

## Karpenter NodePools

### Default NodePool
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.sh/provider
          operator: In
          values: ["aws"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
```

### EC2 NodeClass
```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  role: "KarpenterNodeRole"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "true"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "true"
  tags:
    Environment: "production"
    Team: "platform"
```

---

## Provisioning Workflow

### GitOps Trigger
```yaml
# File: environments/sandbox/namespaces/team-alpha.yaml
apiVersion: platform.openclaw.io/v1alpha1
kind: Namespace
metadata:
  name: team-alpha
spec:
  quota:
    cpu: "10"
    memory: "20Gi"
    pods: "50"
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: team-alpha
spec:
  source:
    path: environments/sandbox/namespaces/team-alpha
  destination:
    server: https://kubernetes.default.svc
```

### Kafka Instruction
```json
{
  "topic": "agent-instructions",
  "value": {
    "instruction_id": "INST-002",
    "target_agent": "infrastructure-agent",
    "action": "provision_namespace",
    "parameters": {
      "environment": "sandbox",
      "namespace": "team-alpha",
      "quota": {
        "cpu": "10",
        "memory": "20Gi",
        "pods": "50"
      }
    }
  }
}
```

### Agent Execution
```python
class InfrastructureAgent:
    def provision_namespace(self, params):
        # 1. Create Kubernetes namespace
        ns = kubernetesclient.create_namespace(params.name)
        
        # 2. Apply resource quotas
        quota = kubernetesclient.create_resource_quota(
            params.name, params.quota
        )
        
        # 3. Configure network policies
        network_policy = kubernetesclient.apply_network_policy(
            params.name
        )
        
        # 4. Set up IAM role for namespace
        iam_client.create_role_for_namespace(
            params.name, params.environment
        )
        
        return {
            "namespace": params.name,
            "resources_created": ["namespace", "resourcequota", "networkpolicy", "iam-role"]
        }
```

---

## Self-Scaling

### Scale-Up Trigger
```
High CPU/memory usage (>80% for 2min) →
Karpenter launches new spot nodes →
Workloads automatically distributed →
Cost optimized
```

### Scale-Down Trigger
```
Low utilization (<20% for 5min) →
Karpenter consolidates nodes →
Workloads moved to fewer nodes →
Nodes terminated
```

---

## AWS Resource Types

| Resource | Crossplane Kind | Use Case |
|----------|-----------------|-----------|
| **EKS Cluster** | EKSCluster | Kubernetes control plane |
| **Node Group** | EKSNodeGroup | Managed node groups |
| **RDS** | RDSInstance | PostgreSQL, MySQL databases |
| **S3** | S3Bucket | Object storage |
| **VPC** | VPC | Virtual network |
| **Subnets** | Subnet | AZ isolation |
| **Security Groups** | SecurityGroup | Network access control |
| **Route53** | Route53Record | DNS records |

---

## Deployment

### Prerequisites
- Control Tower deployed
- Crossplane AWS provider configured
- Karpenter compatible AMI

### Installation
```bash
# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace

# Install Crossplane AWS Provider
kubectl apply -f crossplane-provider-aws/

# Install Karpenter
kubectl apply -k https://github.com/kubernetes-sigs/karpenter?ref=v1.0.0

# Deploy Infrastructure Agent
kubectl apply -f infrastructure-agent/
```

---

## Verification

```bash
# Check Crossplane resources
kubectl get managed

# Check Karpenter nodes
kubectl get nodes -l karpenter.sh/nodepool

# Verify NodePool
kubectl get nodepool

# Test scaling
kubectl scale deployment test-app --replicas=50
watch kubectl get nodes
```

---

## Demo Script

1. **Commit Scale-Up** — Git commit requesting 5 more nodes
2. **Watch Karpenter** — See nodes launch in real-time
3. **Show Crossplane** — Display created AWS resources
4. **Verify Cost** — Show spot instance savings

---

## Cost Optimization

| Strategy | Implementation |
|----------|----------------|
| **Spot Instances** | Karpenter defaults to spot |
| **Right-Sizing** | LangChain analyzes workload |
| **Consolidation** | Karpenter consolidates when empty |
| **Resource Quotas** | Prevent over-provisioning |
| **Lifecycle Hooks** | Auto-terminate non-production |

---

## Next Steps

- [Applications Agent](/applications-agent) — Deploy GitOps delivery (Week 6)
- [Member Agent](/member-agent) — Deploy identity management (Week 6)
- [Environments](/environments) — Create isolated accounts (Weeks 7-8)
