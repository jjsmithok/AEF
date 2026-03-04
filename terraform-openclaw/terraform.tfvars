# Terraform variables for OpenClaw EC2
# Copy this file to terraform.tfvars and fill in your values

# Server name (used for naming resources)
server_name = "dev-openclaw"

# Model configuration
model_name = "minimax/MiniMax-M2.5"  # Model to use (e.g., minimax/MiniMax-M2.5, anthropic/claude-sonnet-4-5)

# AWS credentials for OpenClaw (needs IAM user credentials)
aws_access_key = ""  # Set your AWS access key
aws_secret_key = ""  # Set your AWS secret key

# Model API Key (MiniMax, OpenAI, Anthropic, etc.)
model_api_key = ""  # Set your model API key

# Telegram Bot Token
telegram_bot_token = ""  # Set your Telegram bot token

# Optional overrides
instance_type    = "t3.medium"
openclaw_version = "2026.2.26"
ssh_key_name     = "openclaw-agent"
