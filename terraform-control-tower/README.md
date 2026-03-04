# Layer 2: Control Tower - Terraform

This Terraform deploys the Control Tower layer to the Control Tower AWS Account (876442841338).

## What It Creates

### In Control Tower Account (876442841338)

1. **Security Group** (`control-tower-sg`)
   - SSH (port 22)
   - Kafka internal (port 9092)
   - Webhook receiver (port 8000)
   - Kafka UI (port 8080)
   - OpenClaw Gateway (port 18789)
   - OpenClaw Browser (port 18791)

2. **IAM Role** (`control-tower-ec2-role`)
   - ReadOnlyAccess
   - CloudWatchLogsFullAccess
   - Instance profile for EC2

3. **EC2 Instance** (`control-tower`)
   - Ubuntu 22.04 LTS
   - t3.large (adjustable)
   - Installs: Docker, Kafka, LangChain, Webhook receiver, OpenClaw

## AWS Logical Separation

```
AWS Organization
├── Root
│   ├── Control Tower (876442841338) ← LAYER 2 HERE
│   │   └── control-tower EC2
│   ├── Environments OU
│   │   ├── Sandbox (605412636532)
│   │   ├── Dev (811890957660)
│   │   ├── Test (949900383634)
│   │   ├── PreProd (490058394713)
│   │   └── Prod (693099116199)
│   ├── Security Tools (853962316430)
│   ├── Monitoring (930975754172)
│   └── Central Logging (263751250645)
```

## Usage

1. Fill in `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your values
   ```

2. Initialize and plan:
   ```bash
   terraform init
   terraform plan
   ```

3. Apply:
   ```bash
   terraform apply
   ```

## Services Running

| Service | URL | Description |
|---------|-----|-------------|
| Kafka | localhost:9092 | Event bus |
| Kafka UI | http://<public-ip>:8080 | Topic monitoring |
| Webhook | http://<public-ip>:8000/webhook | Change Board intake |
| OpenClaw | ws://<public-ip>:18789 | GitOps executor |

## Kafka Topics

- `change-board` - Incoming approved changes
- `agent-instructions.controltower` - Control Tower agent
- `agent-instructions.security` - Security agent
- `agent-instructions.network` - Network agent
- `agent-instructions.infra` - Infrastructure agent
- `audit-events` - Immutable audit log
- `remediation-requests` - Agent collaboration
