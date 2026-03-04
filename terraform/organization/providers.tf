# Terraform Providers and Data Sources
# This file contains the data sources for reading existing AWS resources

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

# Get organization details
data "aws_organization" "org" {
}

# Get root information
data "aws_organizations_roots" "root" {
}

# Helper: Find OU by name
# Usage: data.aws_organizations_organizational_unit.sandbox
data "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "dev" {
  name      = "Dev"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "test" {
  name      = "Test"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "preprod" {
  name      = "PreProd"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "monitoring" {
  name      = "Monitoring"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "logging" {
  name      = "Logging"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "control_tower" {
  name      = "ControlTower"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

data "aws_organizations_organizational_unit" "environments" {
  name      = "Environments"
  parent_id = data.aws_organizations_roots.root.roots[0].id
}

# Get existing account details
data "aws_organizations_account" "security_tools" {
  account_id = "853962316430"
}

data "aws_organizations_account" "monitoring" {
  account_id = "930975754172"
}

data "aws_organizations_account" "central_logging" {
  account_id = "263751250645"
}

data "aws_organizations_account" "control_tower" {
  account_id = "876442841338"
}

output "existing_ous" {
  value = {
    security      = data.aws_organizations_organizational_unit.security.id
    monitoring    = data.aws_organizations_organizational_unit.monitoring.id
    logging       = data.aws_organizations_organizational_unit.logging.id
    control_tower = data.aws_organizations_organizational_unit.control_tower.id
    environments  = data.aws_organizations_organizational_unit.environments.id
  }
}

output "existing_accounts" {
  value = {
    security_tools  = data.aws_organizations_account.security_tools.id
    monitoring      = data.aws_organizations_account.monitoring.id
    central_logging = data.aws_organizations_account.central_logging.id
    control_tower   = data.aws_organizations_account.control_tower.id
  }
}
