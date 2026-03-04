# OpenClaw EC2 Terraform Configuration
# Creates an EC2 instance with OpenClaw pre-installed and configured

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
# VARIABLES
# =====================================================

# Server name (used for naming resources)
variable "server_name" {
  description = "Name for the OpenClaw server (e.g., dev-openclaw)"
  type        = string
  default     = "openclaw"
}

variable "openclaw_version" {
  description = "OpenClaw version to install"
  type        = string
  default     = "2026.2.26"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

# Model configuration
variable "model_name" {
  description = "Model name (e.g., minimax/MiniMax-M2.5)"
  type        = string
  default     = "minimax/MiniMax-M2.5"
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "openclaw-agent"
}

# Sensitive variables - set via terraform.tfvars
variable "aws_access_key" {
  description = "AWS Access Key ID for OpenClaw AWS CLI"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key for OpenClaw AWS CLI"
  type        = string
  default     = ""
  sensitive   = true
}

variable "model_api_key" {
  description = "Model API Key for OpenClaw"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram Bot Token for OpenClaw"
  type        = string
  default     = ""
  sensitive   = true
}

# =====================================================
# RESOURCES
# =====================================================

# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnet
data "aws_subnet" "default" {
  vpc_id = data.aws_vpc.default.id
  
  filter {
    name   = "subnet-id"
    values = ["subnet-00fda6070be51ff77"]
  }
}

# SSH Key Pair - generate locally and import to AWS
resource "tls_private_key" "openclaw" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "openclaw" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.openclaw.public_key_openssh
  
  provisioner "local-exec" {
    command = "echo '${tls_private_key.openclaw.private_key_pem}' > /tmp/${var.ssh_key_name}.pem && chmod 400 /tmp/${var.ssh_key_name}.pem"
  }
}

# Security Group for OpenClaw
resource "aws_security_group" "openclaw" {
  name        = "openclaw-sg"
  description = "Security group for OpenClaw EC2 instance"
  vpc_id      = data.aws_vpc.default.id
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }
  
  # OpenClaw Gateway WebSocket
  ingress {
    from_port   = 18789
    to_port     = 18789
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenClaw Gateway"
  }
  
  # Browser control
  ingress {
    from_port   = 18791
    to_port     = 18791
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenClaw Browser"
  }
  
  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  
  tags = {
    Name = "${var.server_name}-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "openclaw" {
  name = "${var.server_name}-ec2-role"
  
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

# IAM Instance Profile
resource "aws_iam_instance_profile" "openclaw_profile" {
  name = "${var.server_name}-profile"
  role = aws_iam_role.openclaw.name
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.openclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance User Data - OpenClaw Installation Script
locals {
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              echo "=== Starting OpenClaw Installation ==="
              
              # Update and install prerequisites
              apt-get update -qq
              apt-get install -y -qq curl git unzip
              
              # Install Node.js 22
              curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
              apt-get install -y nodejs
              
              # Verify Node.js version
              node --version
              
              # Install AWS CLI v2
              curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
              unzip -q /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install
              rm -rf /tmp/awscliv2.zip /tmp/aws
              
              # Install OpenClaw
              npm install -g openclaw@${var.openclaw_version}
              
              # Create symlink for openclaw
              ln -sf /usr/lib/node_modules/openclaw/openclaw.mjs /usr/local/bin/openclaw
              
              # Configure AWS credentials for OpenClaw
              mkdir -p /home/ubuntu/.aws
              cat > /home/ubuntu/.aws/credentials << 'AWSCREDS'
              [default]
              aws_access_key_id = ${var.aws_access_key}
              aws_secret_access_key = ${var.aws_secret_key}
              AWSCREDS
              
              cat > /home/ubuntu/.aws/config << 'AWSCONFIG'
              [default]
              region = us-east-1
              output = json
              AWSCONFIG
              
              chown -R ubuntu:ubuntu /home/ubuntu/.aws
              
              # Create OpenClaw config directory
              mkdir -p /home/ubuntu/.openclaw
              mkdir -p /home/ubuntu/.openclaw/agents/main/agent
              
              # Create OpenClaw configuration
              cat > /home/ubuntu/.openclaw/openclaw.json << 'OPENCLAWCONFIG'
              {
                gateway: {
                  mode: "local"
                },
                agents: {
                  defaults: {
                    model: "${var.model_name}"
                  }
                },
                channels: {
                  telegram: {
                    enabled: true,
                    botToken: "${var.telegram_bot_token}",
                    dmPolicy: "open",
                    allowFrom: ["*"]
                  }
                }
              }
              OPENCLAWCONFIG
              
              # Create model auth profile
              cat > /home/ubuntu/.openclaw/agents/main/agent/auth-profiles.json << 'MODELAUTH'
              {
                "minimax": {
                  "provider": "minimax",
                  "auth": {
                    "api_key": "${var.model_api_key}"
                  }
                }
              }
              MODELAUTH
              
              chown -R ubuntu:ubuntu /home/ubuntu/.openclaw
              
              # Wait for npm install to complete
              sleep 30
              
              # Start OpenClaw Gateway
              cd /home/ubuntu
              sudo -u ubuntu nohup openclaw gateway > /tmp/openclaw.log 2>&1 &
              
              # Wait for gateway to start
              sleep 15
              
              # Check if running
              if pgrep -f "openclaw-gateway" > /dev/null; then
                  echo "=== OpenClaw Gateway started successfully ==="
              else
                  echo "=== ERROR: OpenClaw Gateway failed to start ==="
                  cat /tmp/openclaw.log
                  exit 1
              fi
              
              echo "=== OpenClaw Installation Complete ==="
              EOF
}

# EC2 Instance
resource "aws_instance" "openclaw" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.openclaw.key_name
  
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.openclaw.id]
  
  iam_instance_profile = aws_iam_instance_profile.openclaw_profile.name
  
  user_data = base64encode(local.user_data)
  
  tags = {
    Name = "${var.server_name}"
    Environment = "Dev"
  }
}

# =====================================================
# OUTPUTS
# =====================================================

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.openclaw.id
}

output "public_ip" {
  description = "EC2 Public IP Address"
  value       = aws_instance.openclaw.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i /tmp/${var.ssh_key_name}.pem ubuntu@${aws_instance.openclaw.public_ip}"
}

output "openclaw_status" {
  description = "Check OpenClaw status"
  value       = "ssh -i /tmp/${var.ssh_key_name}.pem ubuntu@${aws_instance.openclaw.public_ip} 'openclaw status'"
}
