# Variables for Monitoring EC2 Module

variable "environment" {
  description = "Environment name (e.g., poc, prod)"
  type        = string
  default     = "poc"
}

variable "vpc_id" {
  description = "VPC ID for the monitoring EC2"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for the monitoring EC2"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Grafana/OTEL ports"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "instance_type" {
  description = "EC2 instance type (t4g.medium recommended for POC)"
  type        = string
  default     = "t4g.medium"
}

variable "spot_price" {
  description = "Spot instance price in USD (leave empty for on-demand)"
  type        = string
  default     = "" # Empty = on-demand, e.g., "0.02" for spot
}

variable "shutdown_behavior" {
  description = "Behavior when instance is stopped (stop or terminate)"
  type        = string
  default     = "stop"
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "source_account_ids" {
  description = "AWS account IDs that can assume the read-only role"
  type        = list(string)
  default     = []
}

variable "github_repo_url" {
  description = "Git repo URL for docker-compose (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
