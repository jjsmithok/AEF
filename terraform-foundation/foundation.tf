# =====================================================
# FOUNDATION LAYER - Zero Trust IAM & SCPs
# =====================================================

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
# DATA SOURCES - Read Existing AWS Organization
# =====================================================

data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_unit" "environments" {
  name      = "Environments"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

data "aws_organizations_organizational_unit" "control_tower" {
  name      = "ControlTower"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

data "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

# Root OU - use the root ID directly
locals {
  root_id = data.aws_organizations_organization.org.roots[0].id
}

# =====================================================
# SCP 2: DENY HUMAN IAM ACCESS - Apply to Environments OU
# =====================================================

resource "aws_organizations_policy" "deny_human_iam" {
  name        = "DenyHumanIAM"
  description = "Denies human IAM users, access keys, and console login"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMUsers"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile",
          "iam:AddUserToGroup"
        ]
        Resource = ["arn:aws:iam::*:user/*"]
      },
      {
        Sid    = "DenyConsoleLogin"
        Effect = "Deny"
        Action = [
          "aws-portal:*Console*",
          "signin:*"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_human_iam_to_environments" {
  policy_id = aws_organizations_policy.deny_human_iam.id
  target_id = data.aws_organizations_organizational_unit.environments.id
}

# =====================================================
# IAM ROLES FOR AGENTS (4 Parallel Agents + Break-glass)
# =====================================================

# Control Tower Agent - Orchestrates all other agents
resource "aws_iam_role" "controltower_agent" {
  name = "openclaw-controltower"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "controltower_admin" {
  role       = aws_iam_role.controltower_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Security Agent Role
resource "aws_iam_role" "security_agent" {
  name = "openclaw-security"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "security_agent_readonly" {
  role       = aws_iam_role.security_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Network Agent Role
resource "aws_iam_role" "network_agent" {
  name = "openclaw-network"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "network_agent_readonly" {
  role       = aws_iam_role.network_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Infrastructure Agent Role
resource "aws_iam_role" "infra_agent" {
  name = "openclaw-infra"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "infra_agent_readonly" {
  role       = aws_iam_role.infra_agent.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# =====================================================
# BREAK-GLASS ROLE (Time-bound emergency access)
# =====================================================

resource "aws_iam_role" "breakglass" {
  name = "breakglass-audit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::436667402925:root"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "breakglass_admin" {
  role       = aws_iam_role.breakglass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# =====================================================
# OUTPUTS
# =====================================================

output "scp_policy_ids" {
  value = {
    deny_human_iam = aws_organizations_policy.deny_human_iam.id
  }
}

output "iam_roles" {
  value = {
    controltower = aws_iam_role.controltower_agent.arn
    security     = aws_iam_role.security_agent.arn
    network      = aws_iam_role.network_agent.arn
    infra        = aws_iam_role.infra_agent.arn
    breakglass   = aws_iam_role.breakglass.arn
  }
}

output "attached_scps" {
  value = {
    environments = aws_organizations_policy_attachment.deny_human_iam_to_environments.id
  }
}
