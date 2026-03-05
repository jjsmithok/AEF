#!/bin/bash
# =============================================================================
# Control Tower - Start/Stop Demo Script
# =============================================================================

KUBECONFIGset -e

="${KUBECONFIG:-~/.kube/config}"
CLUSTER_NAME="${CLUSTER_NAME:-control-tower}"
REGION="${REGION:-us-east-1}"

if [ "$1" = "start" ]; then
    echo "Starting demo mode..."
    
    # Configure kubectl
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --kubeconfig "$KUBECONFIG"
    
    # Create namespaces
    kubectl create namespace control-tower --kubeconfig="$KUBECONFIG" 2>/dev/null || true
    kubectl create namespace agents --kubeconfig="$KUBECONFIG" 2>/dev/null || true
    
    # Scale up deployments
    echo "Deploying workloads..."
    
elif [ "$1" = "stop" ]; then
    echo "Stopping demo mode (saving money)..."
    
    # Configure kubectl
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --kubeconfig "$KUBECONFIG"
    
    # Scale down all deployments
    for ns in argocd kafka crossplane-system monitoring control-tower agents; do
        echo "  Scaling down $ns..."
        kubectl scale deployment --all --replicas=0 -n "$ns" --kubeconfig="$KUBECONFIG" 2>/dev/null || true
    done
    
    echo ""
    echo "Demo stopped! You are now saving ~\$20-30/month"
    echo "Run './start.sh start' to resume"

else
    echo "Usage: $0 {start|stop}"
    echo ""
    echo "  start  - Start demo mode"
    echo "  stop   - Stop demo mode (save money)"
fi
