# =====================================================
# LAYER 2: CONTROL TOWER - Kafka, LangChain, Webhook
# Deploys to Control Tower AWS Account
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

# =====================================================
# VARIABLES
# =====================================================

variable "control_tower_account_id" {
  description = "AWS Account ID for Control Tower"
  type        = string
  default     = "876442841338"
  sensitive   = true
}

variable "master_account_id" {
  description = "Master/Payer AWS Account ID"
  type        = string
  default     = "436667402925"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "openclaw_version" {
  description = "OpenClaw version"
  type        = string
  default     = "2026.2.26"
}

# Model configuration
variable "model_name" {
  description = "Model name for agents"
  type        = string
  default     = "minimax/MiniMax-M2.5"
}

variable "model_api_key" {
  description = "API key for model"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "kafka_version" {
  description = "Kafka version"
  type        = string
  default     = "3.8.0"
}

variable "instance_type" {
  description = "EC2 instance type for Control Tower"
  type        = string
  default     = "t3.large"
}

# =====================================================
# PROVIDERS - Control Tower Account
# =====================================================

provider "aws" {
  alias  = "control_tower"
  region = var.region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.control_tower_account_id}:role/OrganizationAccountAccessRole"
  }
}

# =====================================================
# DATA SOURCES - Get VPC info from Control Tower
# =====================================================

data "aws_vpc" "default" {
  provider = aws.control_tower
  
  default = true
}

data "aws_subnets" "default" {
  provider = aws.control_tower
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  provider = aws.control_tower
  
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# =====================================================
# SECURITY GROUP - Control Tower
# =====================================================

resource "aws_security_group" "control_tower" {
  provider = aws.control_tower
  
  name        = "control-tower-sg"
  description = "Security group for Control Tower services"
  vpc_id      = data.aws_vpc.default.id
  
  # SSH from anywhere (limited by IAM)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }
  
  # Kafka internal (private)
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Kafka internal"
  }
  
  # Webhook receiver
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Webhook receiver"
  }
  
  # Kafka UI (optional - restrict to source IPs)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kafka UI"
  }
  
  # OpenClaw ports
  ingress {
    from_port   = 18789
    to_port     = 18789
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenClaw Gateway"
  }
  
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
    Name        = "control-tower-sg"
    Environment = "ControlTower"
    Layer       = "Layer2"
  }
}

# =====================================================
# IAM ROLE - Control Tower EC2
# =====================================================

resource "aws_iam_role" "control_tower_role" {
  provider = aws.control_tower
  
  name = "control-tower-ec2-role"
  
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

# Attach policies
resource "aws_iam_role_policy_attachment" "ct_readonly" {
  provider = aws.control_tower
  
  role       = aws_iam_role.control_tower_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ct_cloudwatch" {
  provider = aws.control_tower
  
  role       = aws_iam_role.control_tower_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_instance_profile" "control_tower_profile" {
  provider = aws.control_tower
  
  name = "control-tower-profile"
  role = aws_iam_role.control_tower_role.name
}

# =====================================================
# EC2 INSTANCE - Control Tower
# =====================================================

locals {
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              echo "=== Starting Control Tower Layer 2 Installation ==="
              
              # Update and install prerequisites
              apt-get update -qq
              apt-get install -y -qq curl git unzip docker.io docker-compose-v2 jq
              
              # Start Docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              
              # Install AWS CLI v2
              curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
              unzip -q /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install
              rm -rf /tmp/awscliv2.zip /tmp/aws
              
              # Install Node.js 22
              curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
              apt-get install -y nodejs
              
              # Install OpenClaw
              npm install -g openclaw@${var.openclaw_version}
              
              # Create symlink for openclaw
              ln -sf /usr/lib/node_modules/openclaw/openclaw.mjs /usr/local/bin/openclaw
              
              # Create control-tower directory
              mkdir -p /opt/control-tower
              cd /opt/control-tower
              
              # Create docker-compose.yml for Kafka + LangChain + Webhook
              cat > docker-compose.yml << 'DOCKERCOMPOSE'
              version: '3.8'
              
              services:
                zookeeper:
                  image: confluentinc/cp-zookeeper:7.5.0
                  container_name: zookeeper
                  environment:
                    ZOOKEEPER_CLIENT_PORT: 2181
                    ZOOKEEPER_TICK_TIME: 2000
                  volumes:
                    - zookeeper-data:/var/lib/zookeeper/data
                    - zookeeper-logs:/var/lib/zookeeper/log
                  networks:
                    - control-tower-net
                
                kafka:
                  image: confluentinc/cp-kafka:7.5.0
                  container_name: kafka
                  depends_on:
                    - zookeeper
                  ports:
                    - "9092:9092"
                  environment:
                    KAFKA_BROKER_ID: 1
                    KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
                    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9092
                    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
                    KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
                    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
                    KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
                    KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
                    KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
                  volumes:
                    - kafka-data:/var/lib/kafka/data
                  networks:
                    - control-tower-net
                
                kafka-ui:
                  image: provectuslabs/kafka-ui:latest
                  container_name: kafka-ui
                  depends_on:
                    - kafka
                  ports:
                    - "8080:8080"
                  environment:
                    KAFKA_CLUSTERS_0_NAME: control-tower
                    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
                    KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper:2181
                  networks:
                    - control-tower-net
                
                webhook-receiver:
                  image: python:3.12-slim
                  container_name: webhook-receiver
                  working_dir: /app
                  ports:
                    - "8000:8000"
                  volumes:
                    - ./webhook-receiver:/app
                  command: >
                    bash -c "pip install fastapi uvicorn kafka-python pydantic &&
                            python -m uvicorn app:app --host 0.0.0.0 --port 8000"
                  networks:
                    - control-tower-net
                
                langchain-agent:
                  image: python:3.12-slim
                  container_name: langchain-agent
                  working_dir: /app
                  volumes:
                    - ./langchain:/app
                  command: >
                    bash -c "pip install langchain langchain-community langgraph kafka-python pydantic &&
                            python main.py"
                  environment:
                    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
                    MODEL_NAME: ${var.model_name}
                    MODEL_API_KEY: ${var.model_api_key}
                  networks:
                    - control-tower-net
              
              volumes:
                zookeeper-data:
                zookeeper-logs:
                kafka-data:
              
              networks:
                control-tower-net:
                  driver: bridge
              DOCKERCOMPOSE
              
              # Create webhook receiver app
              mkdir -p webhook-receiver
              cat > webhook-receiver/app.py << 'WEBHOOKAPP'
              from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from kafka import KafkaProducer
import json
import os

app = FastAPI()

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")

try:
    producer = KafkaProducer(
        bootstrap_servers=[KAFKA_BOOTSTRAP],
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )
except Exception as e:
    print(f"Kafka connection failed: {e}")
    producer = None

class WebhookPayload(BaseModel):
    change_id: str
    requested_by: str
    action: str
    resource_type: str
    resource_details: dict

@app.post("/webhook")
async def receive_webhook(payload: WebhookPayload):
    """Receive approved changes from Change Board"""
    if producer is None:
        raise HTTPException(status_code=503, detail="Kafka unavailable")
    
    message = {
        "change_id": payload.change_id,
        "requested_by": payload.requested_by,
        "action": payload.action,
        "resource_type": payload.resource_type,
        "resource_details": payload.resource_details,
        "timestamp": str(datetime.utcnow())
    }
    
    producer.send("change-board", message)
    producer.flush()
    
    return {"status": "accepted", "change_id": payload.change_id}

@app.get("/health")
def health():
    return {"status": "healthy", "kafka": producer is not None}

from datetime import datetime

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
              WEBHOOKAPP
              
              # Create LangChain agent
              mkdir -p langchain
              cat > langchain/main.py << 'LANGCHAINMAIN'
              import os
import json
from kafka import KafkaConsumer
from langchain.chat_models import ChatOpenAI
from langchain.schema import HumanMessage

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
MODEL_NAME = os.getenv("MODEL_NAME", "minimax/MiniMax-M2.5")
MODEL_API_KEY = os.getenv("MODEL_API_KEY", "")

print(f"Starting LangChain agent with model: {MODEL_NAME}")

# Initialize Kafka consumer
consumer = KafkaConsumer(
    'change-board',
    bootstrap_servers=[KAFKA_BOOTSTRAP],
    auto_offset_reset='earliest',
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

print("LangChain agent listening for instructions...")

for message in consumer:
    print(f"Received message: {message.value}")
    
    # Process the instruction and route to appropriate agent
    change = message.value
    resource_type = change.get('resource_type', '')
    action = change.get('action', '')
    
    # Route to agents based on resource type
    agent_topic = None
    if 'security' in resource_type.lower():
        agent_topic = 'agent-instructions.security'
    elif 'network' in resource_type.lower():
        agent_topic = 'agent-instructions.network'
    elif 'infra' in resource_type.lower() or 'ec2' in resource_type.lower() or 's3' in resource_type.lower():
        agent_topic = 'agent-instructions.infra'
    else:
        agent_topic = 'agent-instructions.controltower'
    
    print(f"Routing to: {agent_topic}")
    
    # Log to audit
    audit_entry = {
        **change,
        'processed_by': 'langchain-agent',
        'routed_to': agent_topic
    }
    print(f"Audit: {audit_entry}")

print("LangChain agent shutting down...")
              LANGCHAINMAIN
              
              # Wait for Docker to be ready
              sleep 10
              
              # Start Docker Compose services
              docker compose up -d
              
              # Wait for services
              sleep 30
              
              # Check services
              docker compose ps
              
              echo "=== Control Tower Layer 2 Installation Complete ==="
              echo "Services running:"
              docker compose ps
              EOF
}

resource "aws_instance" "control_tower" {
  provider = aws.control_tower
  
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = tolist(data.aws_subnets.default.ids)[0]
  
  vpc_security_group_ids = [aws_security_group.control_tower.id]
  
  iam_instance_profile = aws_iam_instance_profile.control_tower_profile.name
  
  user_data = base64encode(local.user_data)
  
  tags = {
    Name        = "control-tower"
    Environment = "ControlTower"
    Layer       = "Layer2"
    ManagedBy   = "Terraform"
  }
}

# =====================================================
# OUTPUTS
# =====================================================

output "control_tower_instance_id" {
  description = "EC2 Instance ID for Control Tower"
  value       = aws_instance.control_tower.id
}

output "control_tower_public_ip" {
  description = "Public IP of Control Tower"
  value       = aws_instance.control_tower.public_ip
}

output "control_tower_private_ip" {
  description = "Private IP of Control Tower"
  value       = aws_instance.control_tower.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to Control Tower"
  value       = "ssh ubuntu@${aws_instance.control_tower.public_ip}"
}

output "services" {
  description = "Service URLs"
  value = {
    kafka_ui        = "http://${aws_instance.control_tower.public_ip}:8080"
    webhook_receiver = "http://${aws_instance.control_tower.public_ip}:8000"
    openclaw        = "ws://${aws_instance.control_tower.public_ip}:18789"
  }
}

output "kafka_topics" {
  description = "Kafka topics created"
  value = [
    "change-board",
    "agent-instructions.controltower",
    "agent-instructions.security",
    "agent-instructions.network",
    "agent-instructions.infra",
    "audit-events",
    "remediation-requests"
  ]
}
