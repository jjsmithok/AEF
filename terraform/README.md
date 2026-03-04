# AWS Zero-Trust Terraform

This Terraform configuration manages the AWS Organization for the AI Agent architecture.

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Main configuration |
| `providers.tf` | Data sources for existing AWS resources |
| `organization.tf` | Creates environment accounts + IAM users |
| `scp.tf` | Service Control Policies |

## Usage

### Prerequisites
1. AWS credentials configured (`aws configure`)
2. Terraform installed (>= 1.0)

### Steps

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## What This Creates

### Environment Accounts
- Sandbox
- Dev
- Test
- PreProd
- Prod

### IAM Users (for AI Agents)
- openclaw-security
- openclaw-network
- openclaw-infra
- openclaw-apps

### SCPs
- DenyRootLogin (applied to root)
- DenyHumanConsoleProd (for production restriction)
- SandboxAutoCleanup (for sandbox expiration)

## Important Notes

- Existing OUs and accounts are read via data sources (providers.tf)
- New accounts are created in the Environments OU
- IAM users get ReadOnlyAccess by default
- Access keys are output after creation (store securely!)

## Outputs

After running `terraform apply`, you'll see:
- Environment account IDs
- IAM user names
- Access keys (sensitive - store in password manager)
