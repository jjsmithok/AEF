# AWS Organization - Resource Management
# Creates environment accounts and IAM users for agents
# Assumes organization already exists (uses data from providers.tf)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# =====================================================
# ENVIRONMENT ACCOUNTS (To Create)
# =====================================================

# Sandbox Account
resource "aws_organizations_account" "sandbox" {
  name      = "Sandbox"
  email     = "cs.jsmith101+sandbox@gmail.com"
  parent_id = data.aws_organizations_organizational_unit.environments.id
}

# Dev Account  
resource "aws_organizations_account" "dev" {
  name      = "Dev"
  email     = "cs.jsmith101+dev@gmail.com"
  parent_id = data.aws_organizations_organizational_unit.environments.id
}

# Test Account
resource "aws_organizations_account" "test" {
  name      = "Test"
  email     = "cs.jsmith101+test@gmail.com"
  parent_id = data.aws_organizations_organizational_unit.environments.id
}

# PreProd Account
resource "aws_organizations_account" "preprod" {
  name      = "PreProd"
  email     = "cs.jsmith101+preprod@gmail.com"
  parent_id = data.aws_organizations_organizational_unit.environments.id
}

# Prod Account
resource "aws_organizations_account" "prod" {
  name      = "Prod"
  email     = "cs.jsmith101+prod@gmail.com"
  parent_id = data.aws_organizations_organizational_unit.environments.id
}

# =====================================================
# IAM USERS FOR AGENTS
# =====================================================

resource "aws_iam_user" "security_agent" {
  name = "openclaw-security"
}

resource "aws_iam_user" "network_agent" {
  name = "openclaw-network"
}

resource "aws_iam_user" "infra_agent" {
  name = "openclaw-infra"
}

resource "aws_iam_user" "apps_agent" {
  name = "openclaw-apps"
}

# Create access keys for agents (optional - can also use SSO)
resource "aws_iam_access_key" "security_agent" {
  user = aws_iam_user.security_agent.name
}

resource "aws_iam_access_key" "network_agent" {
  user = aws_iam_user.network_agent.name
}

resource "aws_iam_access_key" "infra_agent" {
  user = aws_iam_user.infra_agent.name
}

resource "aws_iam_access_key" "apps_agent" {
  user = aws_iam_user.apps_agent.name
}

# Attach read-only policies
resource "aws_iam_user_policy_attachment" "security_readonly" {
  user       = aws_iam_user.security_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "network_readonly" {
  user       = aws_iam_user.network_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "infra_readonly" {
  user       = aws_iam_user.infra_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "apps_readonly" {
  user       = aws_iam_user.apps_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# =====================================================
# OUTPUTS
# =====================================================

output "environment_accounts" {
  value = {
    sandbox = aws_organizations_account.sandbox.id
    dev     = aws_organizations_account.dev.id
    test    = aws_organizations_account.test.id
    preprod = aws_organizations_account.preprod.id
    prod    = aws_organizations_account.prod.id
  }
}

output "agent_users" {
  value = {
    security = aws_iam_user.security_agent.name
    network  = aws_iam_user.network_agent.name
    infra    = aws_iam_user.infra_agent.name
    apps     = aws_iam_user.apps_agent.name
  }
}

output "agent_access_keys" {
  value = {
    security = aws_iam_access_key.security_agent.id
    network  = aws_iam_access_key.network_agent.id
    infra    = aws_iam_access_key.infra_agent.id
    apps     = aws_iam_access_key.apps_agent.id
  }
  sensitive = true
}

output "agent_secret_keys" {
  value = {
    security = aws_iam_access_key.security_agent.secret
    network  = aws_iam_access_key.network_agent.secret
    infra    = aws_iam_access_key.infra_agent.secret
    apps     = aws_iam_access_key.apps_agent.secret
  }
  sensitive = true
}
