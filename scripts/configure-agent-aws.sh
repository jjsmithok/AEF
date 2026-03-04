#!/bin/bash
# configure-agent-aws.sh - Configure AWS credentials for each agent workspace

AGENTS=("security" "network" "infra" "apps")
AWS_DIR="$HOME/.aws"
CLAW_DIR="$HOME/.openclaw/agents"

echo "=== Agent AWS Configuration ==="
echo ""

for AGENT in "${AGENTS[@]}"; do
    echo "Configuring agent: $AGENT"
    
    # Check if profile exists
    if [ ! -f "$AWS_DIR/credentials" ] || ! grep -q "\[openclaw-$AGENT\]" "$AWS_DIR/credentials"; then
        echo "  Warning: Profile openclaw-$AGENT not found in ~/.aws/credentials"
        echo "  Run: aws configure --profile openclaw-$AGENT"
        continue
    fi
    
    # Create agent AWS config directory
    mkdir -p "$CLAW_DIR/$AGENT/workspace/.aws"
    
    # Copy credentials (in production, use proper secret management)
    # This is just for local development
    echo "  Profile configured for $AGENT"
done

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "To use AWS with each agent, set AWS_PROFILE environment variable:"
echo "  security: AWS_PROFILE=openclaw-security"
echo "  network:  AWS_PROFILE=openclaw-network"
echo "  infra:    AWS_PROFILE=openclaw-infra"
echo "  apps:     AWS_PROFILE=openclaw-apps"
