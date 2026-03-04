# Monitoring POC - Root Module
# Deploys the monitoring EC2 stack

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store state locally for POC
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"

  # Skip request signing for local/testing
  skip_credentials_validation = false
  skip_metadata_api_check     = false
}

# =====================================================
# CONFIGURATION
# =====================================================

locals {
  # Source accounts to grant read access
  source_accounts = [
    "605412636532", # Sandbox
    "811890957660", # Dev
    "949900383634", # Test
    "490058394713", # PreProd
    "693099116199", # Prod
    "853962316430", # Security
    "876442841338", # Control Tower
  ]

  # CIDR blocks allowed to access (update for your VPC)
  allowed_cidrs = ["10.0.0.0/8"]

  # Optional: Git repo for docker-compose
  # Leave empty to use placeholder
  github_repo = ""
}

# =====================================================
# MODULE: Monitoring EC2
# =====================================================

module "monitoring_ec2" {
  source = "./modules/monitoring-ec2"

  # Core settings
  environment       = "poc"
  instance_type     = "t4g.medium" # 4GB RAM minimum for observability stack
  volume_size_gb    = 30
  shutdown_behavior = "stop" # Important: allows stop/start for testing

  # Network
  allowed_cidr_blocks = local.allowed_cidrs

  # Cross-account access
  source_account_ids = local.source_accounts

  # Git repo (optional)
  github_repo_url = local.github_repo

  tags = {
    Project     = "AI-Enterprise-Control-Tower"
    Environment = "POC"
  }
}

# =====================================================
# OUTPUTS
# =====================================================

output "monitoring_instance_id" {
  description = "EC2 Instance ID"
  value       = module.monitoring_ec2.instance_id
}

output "monitoring_public_ip" {
  description = "Public IP for Grafana access"
  value       = module.monitoring_ec2.instance_public_ip
}

output "grafana_url" {
  description = "Grafana URL (via SSM or public IP)"
  value       = "http://${module.monitoring_ec2.instance_public_ip}:3000"
}

output "ssm_access_command" {
  description = "Command to access instance via SSM"
  value       = "aws ssm start-session --target ${module.monitoring_ec2.instance_id}"
}

output "s3_bucket" {
  description = "Telemetry S3 bucket"
  value       = module.monitoring_ec2.s3_telemetry_bucket
}

output "iam_role_arn" {
  description = "Cross-account read IAM role"
  value       = module.monitoring_ec2.iam_readonly_role_arn
}
