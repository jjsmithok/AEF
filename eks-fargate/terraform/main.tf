# =============================================================================
# EKS Fargate Terraform - Main Configuration
# =============================================================================
# Cost: ~$20-30/month (Fargate)
# =============================================================================

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
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "control-tower"
}

# Use existing VPC or create new
variable "use_existing_vpc" {
  default = true
}

variable "vpc_id" {
  default = ""  # Enter your VPC ID if use_existing_vpc = true
}

variable "subnet_ids" {
  default = []  # Enter your subnet IDs if use_existing_vpc = true
}

# =============================================================================
# EKS Fargate Module
# =============================================================================

module "eks_fargate" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  # Fargate profiles for different namespaces
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        { namespace = "kube-system" },
        { namespace = "default" }
      ]
    }
  }

  # Use existing VPC
  vpc_id     = var.use_existing_vpc ? var.vpc_id : module.vpc.vpc_id
  subnet_ids = var.use_existing_vpc ? var.subnet_ids : module.vpc.private_subnets

  tags = {
    Environment = "demo"
    Project    = "Control-Tower"
  }
}

# Create VPC if needed
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  count = var.use_existing_vpc ? 0 : 1

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "demo"
    Project    = "Control-Tower"
  }
}

# =============================================================================
# Auto-Start/Stop Lambda (Optional)
# =============================================================================

# This Lambda function can scale Fargate tasks up/down based on schedule
# Cost: ~$1/month to run

resource "aws_iam_role" "lambda_role" {
  count = 0  # Enable if using Lambda

  name = "${var.cluster_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_fargate.cluster_endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
}

output "cost_estimate" {
  value = <<-EOT
    Monthly Cost:
    - EKS Cluster: $0
    - Fargate Pods: ~$20-30/month
    - When Stopped: $0
  EOT
}
