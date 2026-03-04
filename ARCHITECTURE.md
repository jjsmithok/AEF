# AWS Zero-Trust Multi-Agent Architecture
## Version 3.0 - EC2-Based (Simplified)

> Status: In Progress
> Date: 2026-02-27
> Architecture: EC2-based (no EKS)

---

## Executive Summary

This document describes a zero-trust AWS organization with AI agents running on EC2 instances, using IAM roles with zero long-lived credentials. Simplified from EKS-based design for faster deployment.

---

## 1. AWS Organization Structure

```
AWS Organization Root (Payer Account: 436667402925)
│
├── 🏢 Management OU
│   └── Master Account (payer, billing)
│
├── 🔒 Security OU  
│   └── Security Tools Account (853962316430)
│
├── 📊 Logging OU
│   └── Central Logging Account (263751250645)
│
├── 📈 Monitoring OU
│   └── Monitoring Account (930975754172)
│
├── 🎛️ Control Tower OU
│   └── Control Tower Account (876442841338)
│       - OpenClaw Agent (EC2)
│
└── 🏭 Environments OU
    ├── 🧪 Sandbox (605412636532)
    ├── 💻 Dev (811890957660)
    ├── 🧬 Test (949900383634)
    ├── 🚀 PreProd (490058394713)
    └── ⚠️ Prod (693099116199)
```

---

## 2. Agent Architecture (EC2-Based)

### Current Setup
- **Host**: EC2 t3.medium (i-0dcff897afc949b7b)
- **IP**: 54.144.225.124
- **Region**: us-east-1
- **Agent**: OpenClaw

### IAM Users (to be deprecated)
| User | Purpose | Status |
|------|---------|--------|
| openclaw-security | Security operations | Pending deprecation |
| openclaw-network | Network operations | Pending deprecation |
| openclaw-infra | Infra operations | Pending deprecation |
| openclaw-apps | Apps/DevOps | Pending deprecation |

---

## 3. Simplified Layer 1 (EC2)

### What's Needed

| Component | Status | Notes |
|-----------|--------|-------|
| EC2 Server | ✅ Running | t3.medium |
| OpenClaw Agent | ⏳ Not installed | Run on EC2 |
| IAM Roles | ⏳ Not created | Use instance profile |
| SCPs | ❌ Not applied | Optional for now |
| GitHub Repo | ✅ Ready | jjsmithok/openclaw-business |

---

## 4. Deployment Steps

### Step 1: Connect to EC2
```bash
ssh -i ~/.ssh/openclaw-agent.pem ec2-user@54.144.225.124
```

### Step 2: Install OpenClaw
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g openclaw
```

### Step 3: Configure
```bash
openclaw configure
# Enter AWS credentials
```

### Step 4: Start Agent
```bash
openclaw start
```

---

## 5. Zero-Trust Principles (Simplified)

| Principle | Implementation |
|-----------|---------------|
| **Least privilege** | IAM instance profile with specific permissions |
| **Rotate credentials** | Use EC2 instance profile (no long-lived keys) |
| **Audit everything** | CloudTrail enabled org-wide |
| **Network isolation** | Security groups restrict access |

---

## 6. Cost Estimate

| Component | Monthly Cost |
|-----------|-------------|
| EC2 t3.medium | ~$30 |
| EIP (1) | ~$4 |
| CloudTrail | ~$20 |
| **Total** | **~$54/month** |

---

## 7. Next Steps

1. ✅ EC2 server running
2. ⏳ Install OpenClaw on EC2
3. ⏳ Configure agent with AWS credentials
4. ⏳ Test agent functionality
5. ⏳ Set up GitHub Actions for automation

---

*Last Updated: 2026-02-27*
