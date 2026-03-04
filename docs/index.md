---
title: AI Enterprise Control Tower
description: Complete documentation for the autonomous AWS Control Tower with 5 AI Agents
---

# AI Enterprise Control Tower

> **100% OSS | Zero-Touch Post-Bootstrap | GitHub-First CI/CD | Rebaselined February 2026**

A fully autonomous, zero-trust enterprise infrastructure platform built on AWS with 5 AI Agents.

![Banner](/assets/banner.jpg)

## Why Control Tower?

- **Autonomous** — 5 AI Agents self-heal and self-provision
- **Zero-Trust** — mTLS everywhere, least-privilege IAM, SCPs
- **GitHub-First** — All changes via PR → GitHub Actions → ArgoCD
- **100% OSS** — All components are open-source

## Architecture

The Control Tower manages **5 autonomous AI Agents** running as Knative services across **5 isolated AWS environments**, orchestrated via Apache Kafka.

```
Change Board → Control Tower (EKS + Kafka) → 5 Agents → 5 Environments
                            ↓
                    Monitoring (Read-Only)
```

## Quick Links

<CardGroup cols={2}>
  <Card title="Foundation Layer" href="/foundation" icon="shield-check">
    IAM, Bootstrap, GitOps - Week 1
  </Card>
  <Card title="Control Tower" href="/control-tower" icon="brain">
    Kafka, LangChain Orchestration - Weeks 2-3
  </Card>
  <Card title="Security Agent" href="/security-agent" icon="lock-closed">
    Kyverno, Falco, Policy Enforcement
  </Card>
  <Card title="Network Agent" href="/network-agent" icon="globe">
    Cilium, Istio, Zero-Trust Networking
  </Card>
  <Card title="Infrastructure Agent" href="/infrastructure-agent" icon="server">
    Crossplane, Karpenter, Auto-scaling
  </Card>
  <Card title="Environments" href="/environments" icon="layers">
    5 Isolated AWS Accounts
  </Card>
</CardGroup>

## Technology Stack

| Category | Technology |
|----------|------------|
| **Kubernetes** | EKS 1.31 |
| **Service Mesh** | Istio 1.23 |
| **CNI** | Cilium 1.16 (eBPF) |
| **Serverless** | Knative Serving + Eventing |
| **Event Bus** | Strimzi Kafka |
| **GitOps** | ArgoCD 2.12+ |
| **IaC** | OpenTofu, Crossplane |
| **Observability** | Prometheus, Loki, Tempo, Grafana |

## Environments

| Environment | Purpose | Policy |
|-------------|---------|--------|
| **Sandbox** | Development & testing | Lenient |
| **Dev** | Agent development | Moderate |
| **Test** | Integration testing | Strict |
| **Staging** | Pre-production | Production-like |
| **Prod** | Live operations | Deny-all |

## Get Started

1. **[Foundation Layer](/foundation)** — Start here to establish identity and GitOps
2. **[Architecture Diagrams](/diagrams)** — Visual overview of the system
3. **[Environments](/environments)** — Create isolated AWS accounts

---

<Card title="Contributing" icon="git-branch" href="/CONTRIBUTING">
  Learn how to edit and contribute to this documentation
</Card>
