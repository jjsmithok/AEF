# AWS Zero-Trust Multi-Agent Architecture - As Built Design Document

> **Document Status:** Ready for Implementation  
> **Date:** 2026-02-26  
> **Version:** 2.0

---

## 1. Executive Summary

This document describes a comprehensive zero-trust AWS organization structure with 5 autonomous AI agents running as Kubernetes pods in the Control Tower account. The architecture uses IAM Roles for Service Accounts (IRSA) with zero long-lived credentials, implementing defense-in-depth security principles.

### Key Highlights
- **5 AI Agents** operating autonomously across AWS accounts
- **10 AWS Accounts** organized into 6 Organizational Units (OUs)
- **Zero-Trust Model** - no long-lived credentials, all access via IRSA
- **Estimated Monthly Cost:** ~$365/month

---

## 2. AWS Organization Structure

```
AWS Organization Root (Payer Account)
│
├── 🏢 Management OU
│   └── Master Account (payer, billing)
│
├── 🔒 Security OU  
│   └── Security Tools Account
│       - GuardDuty, Inspector, WAF
│       - Security scanning
│
├── 📊 Logging OU
│   └── Central Logging Account
│       - CloudTrail
│       - AWS Config
│       - S3 Audit Vault
│
├── 📈 Monitoring OU
│   └── Read-Only Monitoring Account
│       - Cross-account read-only roles
│       - Grafana dashboards
│       - No secrets, no write access
│
├── 🎛️ Control Tower OU
│   └── AI Enterprise Control Tower Account
│       - EKS Cluster 1.31+
│       - Kafka (Strimzi)
│       - ArgoCD
│       - Knative
│       - LangChain/Haystack
│       - 5 AI Agent Pods
│
└── 🏭 Environments OU
    ├── 🧪 Sandbox (auto-cleanup after 24h)
    ├── 💻 Dev
    ├── 🧬 Test
    ├── 🚀 Pre-Prod
    └── ⚠️ Prod (maximum restrictions)
```

---

## 3. Five Autonomous Agent Roles

### 3.1 Agent Overview

| Agent | Role Name | Responsibilities | Kubernetes Namespace |
|-------|-----------|-----------------|---------------------|
| @security | `SecurityAgentRole` | IAM, GuardDuty, KMS, compliance | agents |
| @network | `NetworkAgentRole` | VPC, Subnets, ALB, DNS | agents |
| @infra | `InfraAgentRole` | EC2, RDS, S3, Backups | agents |
| @apps | `AppsAgentRole` | ECS, Lambda, CI/CD | agents |
| @member | `MemberAgentRole` | Identity, Federation, Self-service | agents |

### 3.2 Security Agent Policy

**File:** `policies/security-agent-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListUsers",
        "iam:ListRoles",
        "iam:ListPolicies",
        "guardduty:List*",
        "securityhub:List*",
        "kms:ListKeys"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:*Root*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3.3 Network Agent Policy

**File:** `policies/network-agent-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "elasticloadbalancing:Describe*",
        "route53:List*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3.4 Infrastructure Agent Policy

**File:** `policies/infra-agent-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "rds:Describe*",
        "s3:ListBuckets",
        "s3:GetBucketPolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3.5 Applications Agent Policy

**File:** `policies/apps-agent-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:Describe*",
        "lambda:List*",
        "codebuild:List*",
        "codepipeline:List*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 4. Service Control Policies (SCPs)

### 4.1 DenyRootLogin (Applied to All OUs)

**File:** `scp/deny-root-login.json`

Prevents any root account usage across the organization.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootLogin",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalARN": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

### 4.2 DenyDirectHumanAccess (Production Only)

**File:** `scp/deny-human-console-prod.json`

Prevents human access to Production console except via BreakGlass role.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyHumanConsole",
      "Effect": "Deny",
      "Action": [
        "aws-portal:*Console*",
        "signin:*"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalARN": "arn:aws:iam::*:role/BreakGlassRole"
        }
      }
    }
  ]
}
```

### 4.3 SandboxAutoCleanup

**File:** `scp/sandbox-auto-cleanup.json`

Automatically prevents resource creation in Sandbox after 24 hours.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AutoDeleteResources",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance",
        "s3:CreateBucket"
      ],
      "Resource": "*",
      "Condition": {
        "DateGreaterThan": {
          "aws:CurrentTime": "2026-02-27T00:00:00Z"
        }
      }
    }
  ]
}
```

---

## 5. Network Architecture

### 5.1 Per-Account VPC Design

Each AWS account gets its own VPC with three-tier subnet architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                   Each Account                              │
│                                                              │
│  VPC: 10.x.0.0/16                                          │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Public Subnet   │  │  Private App    │                  │
│  │   (ALB, NAT)    │  │   Subnet        │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                              │
│  ┌─────────────────┐                                       │
│  │  Private Data   │                                       │
│  │   Subnet        │                                       │
│  │ (RDS, Elasti)  │                                       │
│  └─────────────────┘                                       │
│                                                              │
│  Transit Gateway → Central Network Account                   │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 CIDR Allocation (No Overlap)

| Account | VPC CIDR | Public Subnet | Private App | Private Data |
|---------|----------|---------------|-------------|--------------|
| Sandbox | 10.0.0.0/18 | .0/24 | .64/26 | .128/26 |
| Dev | 10.1.0.0/18 | .0/24 | .64/26 | .128/26 |
| Test | 10.2.0.0/18 | .0/24 | .64/26 | .128/26 |
| PreProd | 10.3.0.0/18 | .0/24 | .64/26 | .128/26 |
| Prod | 10.4.0.0/18 | .0/24 | .64/26 | .128/26 |

---

## 6. Control Tower EKS Cluster

### 6.1 Cluster Specifications

- **Kubernetes Version:** 1.31+
- **Node Type:** 3x m6i.xlarge (spot instances)
- **CNI:** Cilium
- **Autoscaling:** Karpenter
- **GitOps:** ArgoCD
- **Policy Engine:** Kyverno
- **Messaging:** Strimzi (Kafka)
- **Serverless:** Knative

### 6.2 Agent Pod Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: security-agent
  namespace: agents
spec:
  replicas: 1
  selector:
    matchLabels:
      app: security-agent
  template:
    metadata:
      labels:
        app: security-agent
    spec:
      serviceAccountName: security-agent
      containers:
      - name: agent
        image: openclaw/openclaw:latest
        env:
        - name: AWS_ROLE_ARN
          value: "arn:aws:iam::ACCOUNT_ID:role/SecurityAgentRole"
        - name: AWS_WEB_IDENTITY_TOKEN_FILE
          value: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
```

---

## 7. Zero-Trust Principles Implementation

| Principle | Implementation |
|-----------|---------------|
| **Never trust, always verify** | IRSA with web identity tokens |
| **Least privilege** | Agent-specific IAM policies with deny-by-default |
| **Assume breach** | Micro-segmentation, no implicit trust between accounts |
| **Verify explicitly** | All actions via GitOps (ArgoCD) and webhooks |
| **Micro-segmentation** | Per-account VPC, security groups, NACLs |
| **Zero human access** | SCPs deny console except via BreakGlass role |
| **Audit everything** | CloudTrail to centralized logging account |

---

## 8. Implementation Files

### Directory Structure

```
aws-zero-trust/
├── ARCHITECTURE.md          # This document
├── terraform/
│   ├── main.tf              # EKS cluster configuration
│   ├── organization.tf      # AWS Org structure
│   └── outputs.tf           # Cross-account outputs
├── policies/
│   ├── security-agent-policy.json
│   ├── network-agent-policy.json
│   ├── infra-agent-policy.json
│   └── apps-agent-policy.json
├── scp/
│   ├── deny-root-login.json
│   ├── deny-human-console-prod.json
│   └── sandbox-auto-cleanup.json
└── scripts/
    ├── configure-agent-aws.sh
    └── create-agents.sh
```

---

## 9. Deployment Roadmap

### Phase 1: Organization (Day 1)
- [ ] Create AWS Organization
- [ ] Create OUs (Management, Security, Logging, Monitoring, Control, Environments)
- [ ] Create member accounts via Terraform/OpenTofu)

### Phase 2: SCPs (Day 1)
- [ ] Apply DenyRootLogin SCP to all OUs
- [ ] Apply DenyDirectHumanAccess to Prod OU
- [ ] Apply SandboxAutoCleanup to Sandbox OU

### Phase 3: Control Tower (Day 2)
- [ ] Deploy EKS cluster (1.31+)
- [ ] Install add-ons (ArgoCD, Karpenter, Cilium, etc.)
- [ ] Configure IRSA for all agent service accounts

### Phase 4: Agent Deployment (Day 3)
- [ ] Deploy 5 agent pods (security, network, infra, apps, member)
- [ ] Configure cross-account IAM role assumptions
- [ ] Test webhook integration

### Phase 5: First Deployment (Day 5)
- [ ] Test Change Board webhook integration
- [ ] Deploy test workload to Sandbox
- [ ] Verify auto-cleanup policy works

---

## 10. Cost Breakdown

| Component | Monthly Estimate |
|-----------|-----------------|
| EKS Cluster (3x m6i.xlarge spot) | ~$150 |
| NAT Gateways (5 accounts) | ~$175 |
| CloudTrail | ~$20 |
| GuardDuty | ~$10 |
| S3 (minimal logs) | ~$10 |
| **Total** | **~$365/month** |

---

## 11. Configuration Scripts

### 11.1 Configure Agent AWS

**File:** `scripts/configure-agent-aws.sh`

Configures AWS credentials for each agent workspace using named profiles.

### 11.2 Create Agents

**File:** `scripts/create-agents.sh`

Bootstrap script to create IAM roles and Kubernetes service accounts for all 5 agents.

---

## 12. Next Steps

1. **Configure AWS Credentials** - Run `aws configure` or use AWS SSO
2. **Deploy Organization** - Run `terraform apply` in terraform/ directory
3. **Set up EKS** - Deploy Control Tower cluster
4. **Deploy Agents** - Run create-agents.sh
5. **Configure Webhooks** - Connect to Change Board for autonomous operation

---

*Document Prepared: 2026-02-26*  
*Project: aws-zero-trust*  
*Location: /home/opencl02/.openclaw/workspace-acpro/aws-zero-trust/*
