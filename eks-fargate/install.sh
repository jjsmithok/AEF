#!/bin/bash
# =============================================================================
# Control Tower - Quick Install Script
# Updated: March 2026
# =============================================================================

set -e

KUBECONFIG="${KUBECONFIG:-~/.kube/config}"
CLUSTER_NAME="${CLUSTER_NAME:-control-tower}"
REGION="${REGION:-us-east-1}"

echo "============================================"
echo "Control Tower - Quick Install"
echo "============================================"

# Check if cluster exists
echo "[1/5] Checking cluster..."
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "ERROR: Cluster '$CLUSTER_NAME' does not exist!"
    echo "Create it with: eksctl create cluster --name $CLUSTER_NAME --region $REGION --fargate"
    exit 1
fi
echo "Cluster '$CLUSTER_NAME' exists."

# Configure kubectl
echo "[2/5] Configuring kubectl..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --kubeconfig "$KUBECONFIG"

# Create Fargate profiles
echo "[3/5] Creating Fargate profiles..."
for ns in argocd kafka crossplane-system monitoring control-tower agents; do
    echo "  Creating Fargate profile for: $ns"
    eksctl create fargateprofile --cluster "$CLUSTER_NAME" --region "$REGION" --name "$ns" --namespace "$ns" 2>/dev/null || true
done

# Install ArgoCD
echo "[4/5] Installing ArgoCD..."
kubectl create namespace argocd --kubeconfig="$KUBECONFIG" 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --kubeconfig="$KUBECONFIG"

# Install Crossplane
echo "[5/5] Installing Crossplane..."
kubectl create namespace crossplane-system --kubeconfig="$KUBECONFIG" 2>/dev/null || true
helm repo add crossplane-stable https://charts.crossplane.io/stable --kubeconfig="$KUBECONFIG"
helm install crossplane crossplane-stable/crossplane -n crossplane-system --kubeconfig="$KUBECONFIG"

echo ""
echo "============================================"
echo "Installation complete!"
echo "============================================"
echo ""
echo "Wait a few minutes for pods to start, then run:"
echo "  kubectl get pods -A"
echo ""
echo "Access ArgoCD:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
