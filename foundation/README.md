# Foundation Layer: IAM Roles & Bootstrap

> **Week 1** | **Purpose:** Establish permanent zero-trust identity foundation and bootstrap the GitOps engine

---

## Overview

The Foundation Layer establishes the critical infrastructure that enables **zero-trust identity** and **GitOps-driven automation** for the entire Control Tower. This layer is deployed in Week 1 and must be completed before any subsequent layers.

```
┌─────────────────────────────────────────────────────────────────┐
│                    FOUNDATION LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  GitHub PR ──▶ GitHub Actions ──▶ OpenTofu Apply              │
│                                                       │         │
│                                                       ▼         │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ 5 IRSA Roles │  │   SCPs       │  │  ArgoCD Bootstrap   │ │
│  │ + OIDC       │  │ (Organization)│  │  (Control Tower)    │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **IRSA Roles** | AWS IAM + EKS OIDC | Least-privilege identities for each Agent |
| **Baseline SCPs** | AWS Organizations | Deny human console/CLI/SSH except break-glass |
| **ArgoCD Bootstrap** | ArgoCD 2.12+ | GitOps controller for entire estate |
| **Crossplane** | Crossplane 1.16+ | Infrastructure-as-code for all future resources |

---

## Data Flow

### Step 1: GitHub Pull Request
A developer merges a GitHub PR containing role YAML definitions.

### Step 2: GitHub Actions Execution
GitHub Actions (temporary self-hosted runner) executes OpenTofu:

```yaml
# Simplified flow
- name: Apply OpenTofu
  run: |
    tofu init
    tofu plan
    tofu apply -auto-approve
```

### Step 3: IRSA Role Creation
OpenTofu creates IAM roles with IRSA (IAM Roles for Service Accounts) trust policies:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLES"
  },
  "Condition": {
    "StringEquals": {
      "oidc:aud": "sts.amazonaws.com",
      "oidc:sub": "system:serviceaccount:control-tower:security-agent-sa"
    }
  }
}
```

### Step 4: Policy Attachment
Each Agent receives inline policies defining their specific permissions:

| Agent | Permissions |
|-------|-------------|
| Security Agent | GuardDuty + Inspector only |
| Network Agent | VPC, Security Group, Route53 |
| Infrastructure Agent | EC2, EKS, S3, RDS |
| Applications Agent | ECR, CodeDeploy, IAM |
| Member Agent | IAM, Directory Service |

### Step 5: Legacy Credential Deprecation
The `deprecate-iam-users.sh` script:
- Revokes existing `openclaw-*` IAM users
- Deletes access keys
- Ensures no long-lived credentials remain

### Step 6: ArgoCD Installation
ArgoCD is installed via Helm and begins watching the GitHub repo:

```bash
kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd
```

---

## IRSA Role Specifications

### Security Agent Role
```json
{
  "RoleName": "ControlTower-SecurityAgent-Role",
  "AssumeRolePolicy": {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/..."
      },
      "Condition": {
        "StringEquals": {
          "oidc:sub": "system:serviceaccount:control-tower:security-agent-sa"
        }
      }
    }]
  },
  "Policies": [
    "GuardDutyReadOnly",
    "InspectorReadOnly"
  ]
}
```

### Network Agent Role
```json
{
  "RoleName": "ControlTower-NetworkAgent-Role",
  "Permissions": [
    "ec2:Describe*",
    "ec2:CreateSecurityGroup",
    "ec2:AuthorizeSecurityGroupIngress",
    "route53:ListHostedZones",
    "elasticloadbalancing:Describe*"
  ]
}
```

### Infrastructure Agent Role
```json
{
  "RoleName": "ControlTower-InfraAgent-Role",
  "Permissions": [
    "eks:*",
    "ec2:*",
    "s3:*",
    "rds:*",
    "karpenter:*"
  ]
}
```

### Applications Agent Role
```json
{
  "RoleName": "ControlTower-AppsAgent-Role",
  "Permissions": [
    "ecr:*",
    "codedeploy:*",
    "iam:GetRole",
    "iam:PassRole"
  ]
}
```

### Member Agent Role
```json
{
  "RoleName": "ControlTower-MemberAgent-Role",
  "Permissions": [
    "iam:CreateUser",
    "iam:AddUserToGroup",
    "iam:CreateLoginProfile",
    "ds:DescribeDirectories"
  ]
}
```

---

## Service Control Policies (SCPs)

### Deny Human Console Access
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyConsoleAccess",
    "Effect": "Deny",
    "Action": [
      "aws:ConsoleLogin",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice"
    ],
    "Resource": "*",
    "Condition": {
      "BoolIfExists": {
        "aws:MultiFactorAuthPresent": "false"
      }
    }
  }]
}
```

### Deny IAM User Creation
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyIAMUserCreation",
    "Effect": "Deny",
    "Action": [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile"
    ],
    "Resource": "*"
  }]
}
```

### Allow Break-Glass (Time-Bound)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowBreakGlass",
    "Effect": "Allow",
    "Action": ["*"],
    "Resource": "*",
    "Condition": {
      "StringEquals": {
        "aws:PrincipalTag/break-glass": "true"
      },
      "DateLessThan": {
        "aws:CurrentTime": "2026-03-15T00:00:00Z"
      }
    }
  }]
}
```

---

## Security & Zero-Touch Controls

| Control | Implementation |
|---------|----------------|
| **No Long-Lived Credentials** | All IAM users deprecated after Week 1 |
| **Temporary Credentials** | Pods receive 15-minute credentials via AWS STS |
| **SCPs** | Block `iam:CreateUser`, console login, except break-glass |
| **OIDC Authentication** | EKS cluster uses OIDC provider for pod identity |
| **Audit Logging** | All API calls logged to CloudTrail |

---

## Post-Week 1 Verification

Run these commands to verify Foundation Layer is properly deployed:

```bash
# Verify no IAM users exist
aws iam list-users

# Verify IRSA roles exist
aws iam list-roles | grep "ControlTower-"

# Verify ArgoCD is running
kubectl get pods -n argocd

# Verify OIDC provider is configured
aws iam list-open-id-connect-providers
```

---

## Demo Script (End of Week 1)

1. **Show PR Merged** — Display GitHub PR with role YAMLs
2. **Show Actions Log** — Display GitHub Actions workflow execution
3. **Verify No Users** — Run `aws iam list-users` → should return empty
4. **Attempt Old Key Access** — Try using deprecated keys → `Access Denied`

---

## Next Steps

- [Control Tower Layer](/control-tower) — Deploy the brain (Weeks 2-3)
- [Environment Provisioning](/environments) — Create isolated AWS accounts
