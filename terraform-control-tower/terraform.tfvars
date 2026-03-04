# =====================================================
# TERRAFORM VARIABLES - Layer 2 Control Tower
# =====================================================

# AWS Account Configuration
control_tower_account_id = "876442841338"
master_account_id        = "436667402925"
region                  = "us-east-1"

# EC2 Configuration
instance_type     = "t3.large"
openclaw_version  = "2026.2.26"

# Model Configuration (for LangChain agents)
model_name = "minimax/MiniMax-M2.5"  # Model to use

# Sensitive - Fill in your values
model_api_key      = ""  # Your MiniMax API key
telegram_bot_token = ""  # Your Telegram bot token (optional for now)

# Kafka Configuration
kafka_version = "3.8.0"
