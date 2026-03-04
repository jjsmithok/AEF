# Monitoring EC2 Module - POC v2.1
# Simplified EC2-based observability plane

# =====================================================
# LOCAL VALUES
# =====================================================

locals {
  name_prefix = "monitoring-${var.environment}"
  common_tags = merge(
    {
      Project     = "AI-Enterprise-Control-Tower"
      Component   = "Monitoring-POC"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# =====================================================
# VPC & SUBNET (use defaults if not provided)
# =====================================================

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id]
  }
}

locals {
  vpc_id    = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_id = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default[0].ids[0]
}

# =====================================================
# IAM INSTANCE PROFILE & ROLE (Cross-Account Read)
# =====================================================

resource "aws_iam_role" "monitoring_readonly" {
  name = "${local.name_prefix}-readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.monitoring_readonly.name

  tags = local.common_tags
}

# Policy for cross-account read access
resource "aws_iam_policy" "cross_account_read" {
  name = "${local.name_prefix}-cross-account-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "lambda:Get*",
          "lambda:List*",
          "s3:GetBucket*",
          "s3:ListBucket*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "guardduty:List*",
          "guardduty:Get*",
          "securityhub:Describe*",
          "securityhub:Get*",
          "securityhub:List*",
          "ce:Get*",
          "ce:Describe*",
          "config:Describe*",
          "config:Get*",
          "config:List*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = var.source_account_ids
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "ec2:*Create*",
          "ec2:*Delete*",
          "ec2:*Modify*",
          "rds:*Create*",
          "rds:*Delete*",
          "rds:*Modify*",
          "s3:*Delete*",
          "s3:*Put*",
          "lambda:*Invoke*",
          "lambda:*Create*",
          "lambda:*Delete*",
          "cloudwatch:Put*",
          "cloudwatch:Set*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cross_account_read" {
  role       = aws_iam_role.monitoring_readonly.name
  policy_arn = aws_iam_policy.cross_account_read.arn
}

# =====================================================
# SECURITY GROUP
# =====================================================

resource "aws_security_group" "monitoring" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for Monitoring EC2 - ports for Grafana, OTEL"
  vpc_id      = local.vpc_id

  # Grafana - HTTP
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Grafana HTTP"
  }

  # Prometheus/OTEL
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Prometheus/OTEL HTTP"
  }

  # Loki
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Loki HTTP"
  }

  # OTEL Receiver
  ingress {
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "OTEL gRPC"
  }

  ingress {
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "OTEL HTTP"
  }

  # SSH - only from within VPC (via SSM Session Manager)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "SSH (via SSM only)"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = local.common_tags
}

# =====================================================
# S3 BUCKETS FOR TELEMETRY STORAGE
# =====================================================

resource "aws_s3_bucket" "telemetry" {
  bucket = "${local.name_prefix}-telemetry-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "telemetry" {
  bucket = aws_s3_bucket.telemetry.id

  rule {
    id     = "archive-to-ia"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# =====================================================
# EC2 INSTANCE (On-Demand for POC reliability)
# =====================================================

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
}

resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = local.subnet_id

  # Instance Profile
  iam_instance_profile = aws_iam_instance_profile.monitoring.name

  # Shutdown behavior - allows stop/start for testing
  instance_initiated_shutdown_behavior = var.shutdown_behavior

  # Security Group
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  # Root Volume
  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
    tags        = local.common_tags
  }

  # User Data - Docker install + Clone repo
  user_data = templatefile("${path.module}/user-data.sh", {
    github_repo_url = var.github_repo_url
  })

  # Tag
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =====================================================
# EBS DATA VOLUME (Optional)
# =====================================================

resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = local.subnet_id
  size              = var.volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-volume"
  })
}
