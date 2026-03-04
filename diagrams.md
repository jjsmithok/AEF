# Mermaid Diagrams for AWS Control Tower

This file contains Mermaid diagram definitions that can be rendered in Mintlify or any Mermaid-compatible Markdown viewer.

---

## 1. Overall Architecture

```mermaid
flowchart TD
    subgraph ChangeBoard["Change Board"]
        Jira[Jira/ServiceNow]
    end

    subgraph ControlTower["Control Tower"]
        Webhook[Webhook Endpoint]
        Kafka[Strimzi Kafka]
        LangChain[LangChain Orchestration]
    end

    subgraph Agents["5 Autonomous Agents"]
        Sec[Security Agent]
        Net[Network Agent]
        Infra[Infrastructure Agent]
        Apps[Applications Agent]
        Mem[Member Agent]
    end

    subgraph Environments["Environments"]
        Sandbox[Sandbox]
        Dev[Dev]
        Test[Test]
        Staging[Staging]
        Prod[Prod]
    end

    subgraph Monitoring["Monitoring Tower (Read-Only)"]
        Grafana[Grafana]
        Prometheus[Prometheus]
    end

    Jira -->|JSON Payload| Webhook
    Webhook -->|Validate| Kafka
    Kafka --> LangChain
    LangChain -->|Instructions| Sec
    LangChain -->|Instructions| Net
    LangChain -->|Instructions| Infra
    LangChain -->|Instructions| Apps
    LangChain -->|Instructions| Mem

    Sec --> Sandbox & Dev & Test & Staging & Prod
    Net --> Sandbox & Dev & Test & Staging & Prod
    Infra --> Sandbox & Dev & Test & Staging & Prod
    Apps --> Sandbox & Dev & Test & Staging & Prod
    Mem --> Sandbox & Dev & Test & Staging & Prod

    Sandbox & Dev & Test & Staging & Prod -->|Metrics/Logs| Monitoring
    Monitoring --> Graf## 2. Foundation Layer Flow

```mermaid
flowchart LR
    subgraphana
```

---

 Git["GitHub"]
        PR[PR Merged]
    end

    subgraph Actions["GitHub Actions"]
        Tofu[OpenTofu Apply]
    end

    subgraph AWS["AWS Resources"]
        OIDC[OIDC Provider]
        IRSA[5 IRSA Roles]
        SCPs[SCPs]
    end

    subgraph K8s["Kubernetes"]
        ArgoCD[ArgoCD Bootstrap]
    end

    PR --> Tofu
    Tofu -->|Creates| OIDC
    Tofu -->|Creates| IRSA
    Tofu -->|Applies| SCPs
    Tofu -->|Installs| ArgoCD
```

---

## 3. Control Tower Data Flow

```mermaid
sequenceDiagram
    participant CB as Change Board
    participant W as Webhook
    participant K as Kafka
    participant L as LangChain
    participant A as Agent
    participant M as Monitoring

    CB->>W: POST /webhook (JSON)
    W->>W: Validate Signature
    W->>K: Publish to change-board topic
    K->>L: Consume change request
    L->>L: Analyze & decide agent
    L->>K: Publish to agent-instructions
    K->>A: Agent consumes instruction
    A->>A: Execute action
    A->>K: Publish audit-event
    K->>M: Metrics & logs
```

---

## 4. Security Agent Pipeline

```mermaid
flowchart TD
    subgraph Sources["Detection Sources"]
        Kyv[Kyverno]
        Fal[Falco]
        Prom[Prometheus]
    end

    subgraph Pipeline["Event Pipeline"]
        Kafka[Kafka Events]
        Agent[Security Agent]
        LLM[LangChain]
    end

    subgraph Actions["Remediation"]
        Mutate[Mutate Resource]
        Evict[Evict Pod]
        Quarantine[Quarantine Node]
        Alert[Alert Team]
    end

    Kyv -->|Policy Violation| Kafka
    Fal -->|Runtime Alert| Kafka
    Prom -->|Metric Alert| Kafka
    Kafka --> Agent
    Agent --> LLM
    LLM -->|Decision| Mutate
    LLM -->|Decision| Evict
    LLM -->|Decision| Quarantine
    LLM -->|Decision| Alert
```

---

## 5. Network Agent - Zero Trust

```mermaid
flowchart LR
    subgraph Pods["Pods"]
        A[Pod A]
        B[Pod B]
        C[Pod C]
    end

    subgraph Cilium["Cilium (eBPF)"]
        NP[NetworkPolicy]
    end

    subgraph Istio["Istio Service Mesh"]
        MTLS[mTLS Handshake]
        Auth[AuthorizationPolicy]
    end

    subgraph Hubble["Hubble Observability"]
        Flows[Flow Logs]
    end

    A -->|Traffic| B
    B -->|Traffic| C
    A --> NP
    B --> NP
    C --> NP
    NP -->|Enforce| MTLS
    MTLS -->|Verify| Auth
    Flows -->|Log| NP
```

---

## 6. Infrastructure Provisioning

```mermaid
flowchart TD
    subgraph Trigger["GitOps Trigger"]
        Git[Git Commit]
        Argo[ArgoCD Sync]
    end

    subgraph Kafka["Kafka"]
        Inst[agent-instructions]
    end

    subgraph Agent["Infrastructure Agent"]
        Analyze[Analyzer]
        Exec[Executor]
        Verify[Verifier]
    end

    subgraph Crossplane["Crossplane"]
        XRD[XRD Definitions]
        Comp[Compositions]
        MR[Managed Resources]
    end

    subgraph AWS["AWS Resources"]
        EKS[EKS Cluster]
        Karp[Karpenter Nodes]
        RDS[RDS Database]
        S3[S3 Bucket]
    end

    Git --> Argo
    Argo --> Inst
    Inst --> Agent
    Agent --> Analyze
    Agent --> Exec
    Agent --> Verify
    Exec --> Crossplane
    Crossplane --> XRD
    Crossplane --> Comp
    Comp --> MR
    MR --> EKS
    MR --> Karp
    MR --> RDS
    MR --> S3
```

---

## 7. Application Deployment Pipeline

```mermaid
flowchart LR
    subgraph Source["Code & Image"]
        Git[Git Push]
        ECR[ECR Registry]
    end

    subgraph GitOps["ArgoCD"]
        AppSet[ApplicationSet]
        Sync[Sync]
    end

    subgraph Quality["Keptn Quality Gates"]
        Test[Tests]
        Metrics[Metrics]
        Gate[Quality Gate]
    end

    subgraph Envs["Environments"]
        Sandbox[Sandbox]
        Dev[Dev]
        Test[Test]
        Staging[Staging]
        Prod[Prod]
    end

    Git --> ECR
    ECR --> AppSet
    AppSet --> Sync
    Sync -->|Deploy| Sandbox
    Sandbox -->|Promote| Dev
    Dev -->|Promote| Test
    Test -->|Promote| Staging
    Staging -->|Promote| Prod

    Sandbox --> Test
    Test --> Test
    Test --> Gate
    Gate -->|Pass| Next
```

---

## 8. Environments Isolation

```mermaid
flowchart TD
    subgraph Org["AWS Organization"]
        Root[Root]
        
        subgraph OU1["Sandbox OU"]
            SB[111111111111]
        end
        
        subgraph OU2["Dev OU"]
            DV[222222222222]
        end
        
        subgraph OU3["Test OU"]
            TS[333333333333]
        end
        
        subgraph OU4["Staging OU"]
            ST[444444444444]
        end
        
        subgraph OU5["Prod OU"]
            PR[555555555555]
        end
        
        subgraph Shared["Shared Services"]
            Log[Logging]
            Mon[Monitoring]
            Sec[Security]
        end
    end

    Root --> OU1 & OU2 & OU3 & OU4 & OU5 & Shared
    
    SB --- Lenient[Lenient SCPs]
    DV --- Moderate[Moderate]
    TS --- Strict[Strict]
    ST --- Production[Production-like]
    PR --- DenyAll[Deny-All]
```

---

## 9. Playbook Execution Flow

```mermaid
flowchart TD
    subgraph Detect["Detection"]
        Falco[Falco]
        Kyv[Kyverno]
        Prom[Prometheus]
    end

    subgraph Kafka["self-healing topic"]
        Event[Anomaly Event]
    end

    subgraph Agent["Agent Selection"]
        Router[Route to Agent]
    end

    subgraph Playbook["Playbook Engine"]
        Analyze[Analyze Event]
        Plan[Generate Plan]
        Execute[Execute Actions]
        Verify[Verify Result]
    end

    subgraph Result["Outcome"]
        Success[Success]
        Fail[Failed]
        Alert[Alert On-Call]
    end

    Falco --> Event
    Kyv --> Event
    Prom --> Event
    Event --> Router
    Router --> Analyze
    Analyze --> Plan
    Plan --> Execute
    Execute --> Verify
    Verify -->|OK| Success
    Verify -->|Fail| Fail
    Fail --> Alert
```

---

## 10. Governance - Break Glass

```mermaid
flowchart LR
    subgraph Request["Access Request"]
        User[Human User]
        Teleport[Teleport]
    end

    subgraph Approve["4-Eye Approval"]
        SecLead[Security Lead]
        PlatformLead[Platform Lead]
    end

    subgraph Access["Emergency Access"]
        SSH[SSH Session]
        K8s[ kubectl ]
        DB[Database]
    end

    subgraph Audit["Audit Trail"]
        Record[Session Recording]
        S3[S3 WORM]
    end

    User --> Teleport
    Teleport --> SecLead
    SecLead --> PlatformLead
    PlatformLead -->|Approved| SSH
    PlatformLead -->|Approved| K8s
    PlatformLead -->|Approved| DB
    
    SSH --> Record
    K8s --> Record
    DB --> Record
    Record --> S3
```

---

## Usage in Markdown

To use these diagrams, simply include them in your Markdown files:

````markdown
```mermaid
flowchart TD
    A[Start] --> B[End]
```
````

**Note:** Mintlify supports Mermaid diagrams natively. No additional configuration required.
