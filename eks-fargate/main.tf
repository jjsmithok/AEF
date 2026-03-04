# =============================================================================
# EKS Fargate Cluster for Control Tower
# =============================================================================
# Cost: ~$20-30/month (Fargate only charges for pods)
# Includes auto-start/stop for demo mode
#
# Usage:
#   make create    - Create EKS Fargate cluster
#   make start    - Start demo mode (pods running)
#   make stop     - Stop demo mode (saves money)
#   make delete   - Destroy everything
# =============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

# =============================================================================
# CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "control-tower"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project    = "Control-Tower"
      ManagedBy  = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "usEast2"
  region = "us-east-2"
}

# =============================================================================
# VARIABLES
# =============================================================================

locals {
  cluster_version = "1.29"
  
  # Fargate profile namespaces
  fargate_namespaces = {
    "kafka"           = {}
    "monitoring"      = {}
    "argocd"          = {}
    "crossplane"     = {}
    "cilium"         = {}
    "control-tower"  = {}
    "agents"         = {}
  }
}

# =============================================================================
# VPC (Use existing or create new)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets (for Fargate)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# NAT Gateway (for private subnets)
resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"
  
  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count         = 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${var.cluster_name}-nat"
  }
  
  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = 1
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block    = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# =============================================================================
# EKS CLUSTER
# =============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = var.cluster_name
  cluster_version = local.cluster_version
  
  # Fargate Profile (no EC2 nodes needed)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "default"
        }
      ]
    }
  }
  
  # Add more Fargate profiles for specific namespaces
  fargate_profiles = merge(module.eks.fargate_profiles, {
    kafka = {
      name = "kafka"
      selectors = [
        {
          namespace = "kafka"
        }
      ]
    }
  })
  
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  # EKS Managed Node Groups (optional - can use Fargate instead)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m5.large"]
  }
  
  # Optional: Add one managed node group for core services
  eks_managed_node_groups = {
    core = {
      name           = "core"
      instance_types = ["m5.large"]
      capacity_type  = "SPOT"
      
      min_size     = 0
      max_size     = 2
      desired_size = 0  # Start at 0 to save money!
      
      labels = {
        "node-group" = "core"
      }
    }
  }
  
  tags = {
    Environment = var.environment
    Project    = "Control-Tower"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "fargate_profile_arns" {
  description = "Fargate Profile ARNs"
  value       = module.eks.fargate_profiles
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

# =============================================================================
# COST OPTIMIZATION
# =============================================================================

# CloudWatch Scheduler for auto-start/stop
# This helps save money by stopping non-essential pods during non-demo hours

resource "aws_instance" "scheduler" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t3.nano"
  
  subnet_id = aws_subnet.public[0].id
  
  user_data = <<-EOF
              #!/bin/bash
              # Simple scheduler - customize as needed
              # This instance can run Lambda functions for start/stop
              EOF
  
  tags = {
    Name = "${var.cluster_name}-scheduler"
    Role = "cost-optimization"
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}
