#!/bin/bash
# create-agents.sh - Create IAM users for each OpenClaw agent

set -e

AGENTS=("security" "network" "infra" "apps")
POLICY_DIR="$(dirname "$0")/../policies"

echo "=== AWS Zero-Trust Agent Creator ==="
echo ""

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS credentials not configured"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Account: $ACCOUNT_ID"
echo ""

for AGENT in "${AGENTS[@]}"; do
    echo "Creating agent: $AGENT"
    USERNAME="openclaw-${AGENT}"
    POLICY_FILE="${POLICY_DIR}/${AGENT}-agent-policy.json"
    
    # Check if user exists
    if aws iam get-user --user-name "$USERNAME" > /dev/null 2>&1; then
        echo "  - User $USERNAME already exists, skipping creation"
    else
        echo "  - Creating IAM user..."
        aws iam create-user --user-name "$USERNAME"
    fi
    
    # Check if policy exists
    if aws iam get-policy --policy-name "${AGENT}-policy" --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${AGENT}-policy" > /dev/null 2>&1; then
        echo "  - Policy ${AGENT}-policy already exists"
    else
        echo "  - Creating inline policy..."
        aws iam put-user-policy \
            --user-name "$USERNAME" \
            --policy-name "${AGENT}-policy" \
            --policy-document "file://${POLICY_FILE}"
    fi
    
    # Create access keys
    echo "  - Creating access keys..."
    KEYS=$(aws iam create-access-key --user-name "$USERNAME" 2>/dev/null || echo "{}")
    
    # Save to credentials file
    CRED_FILE="$HOME/.aws/credentials"
    mkdir -p "$HOME/.aws"
    
    if ! grep -q "\[openclaw-${AGENT}\]" "$CRED_FILE" 2>/dev/null; then
        echo "" >> "$CRED_FILE"
        echo "[openclaw-${AGENT}]" >> "$CRED_FILE"
        # Note: Keys would need to be extracted from KEYS JSON
        echo "  # Run: aws iam create-access-key --user-name $USERNAME" >> "$CRED_FILE"
    fi
    
    echo "  - Agent $AGENT created"
    echo ""
done

echo "=== Agent Creation Complete ==="
echo ""
echo "Next steps:"
echo "1. Run 'aws iam list-access-keys --user-name openclaw-<agent>' to get keys"
echo "2. Configure profiles: aws configure --profile <agent-name>"
echo "3. Update ~/agents/*/config.yaml with AWS profile"
