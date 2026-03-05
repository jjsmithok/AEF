#!/bin/bash
# =============================================================================
# EKS Fargate Quick Start Script
# =============================================================================
# Creates EKS Fargate cluster with auto-start/stop capability
# 
# Usage:
#   ./create-cluster.sh          - Create cluster
#   ./start-demo.sh             - Start demo (scale up)
#   ./stop-demo.sh              - Stop demo (scale to zero)
#   ./delete-cluster.sh         - Delete cluster
# =============================================================================

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-control-tower}"
REGION="${REGION:-us-east-1}"
KUBECTL_VERSION="1.29.0"
EKSCTL_VERSION="0.162.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check prerequisites
check_prereq() {
    log_info "Checking prerequisites..."
    
    command -v aws >/dev/null 2>&1 || log_error "AWS CLI not installed"
    command -v kubectl >/dev/null 2>&1 || log_error "kubectl not installed"
    command -v eksctl >/dev/null 2>&1 || log_error "eksctl not installed"
    
    # Check AWS credentials
    aws sts get-caller-identity >/dev/null 2>&1 || log_error "AWS credentials not configured"
    
    log_success "Prerequisites OK"
}

# Create EKS Fargate cluster
create_cluster() {
    log_info "Creating EKS Fargate cluster: $CLUSTER_NAME"
    
    eksctl create cluster \
        --name "$CLUSTER_NAME" \
        --region "$REGION" \
        --fargate \
        --version 1.29 \
        --name="$CLUSTER_NAME" \
        --zones="${REGION}a,${REGION}b" \
        --dry-run=false
    
    log_success "Cluster created!"
    log_info "Configure kubectl: aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
}

# Configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    log_success "Kubectl configured"
}

# Install Kafka
install_kafka() {
    log_info "Installing Kafka..."
    
    kubectl create namespace kafka 2>/dev/null || true
    
    # Install Strimzi
    kubectl create -f https://strimzi.io/install/latest?namespace=kafka -n kafka
    
    # Apply Kafka cluster
    kubectl apply -f - <<EOF -n kafka
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: control-tower-kafka
spec:
  kafka:
    replicas: 3
    version: 3.6.0
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "250m"
        memory: "512Mi"
    storage:
      type: ephemeral
  zookeeper:
    replicas: 3
    resources:
      requests:
        cpu: "50m"
        memory: "128Mi"
      limits:
        cpu: "100m"
        memory: "256Mi"
EOF
    
    log_success "Kafka installed (3 brokers, lightweight config)"
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."
    
    kubectl create namespace argocd 2>/dev/null || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    log_success "ArgoCD installed"
}

# Install Crossplane
install_crossplane() {
    log_info "Installing Crossplane..."
    
    kubectl create namespace crossplane-system 2>/dev/null || true
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm install crossplane crossplane-stable/crossplane -n crossplane-system --create-namespace
    
    log_success "Crossplane installed"
}

# Install monitoring (Prometheus + Grafana)
install_monitoring() {
    log_info "Installing Monitoring..."
    
    kubectl create namespace monitoring 2>/dev/null || true
    
    # Install Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
    
    log_success "Monitoring installed"
}

# Start demo mode
start_demo() {
    log_info "Starting demo mode..."
    
    # Scale up node groups
    eksctl scale nodegroup --cluster="$CLUSTER_NAME" --name=core --nodes-min=1 --nodes-max=3 -region "$REGION" 2>/dev/null || true
    
    # Create namespaces
    kubectl create namespace control-tower 2>/dev/null || true
    kubectl create namespace agents 2>/dev/null || true
    
    log_success "Demo started!"
    kubectl get pods -A
}

# Stop demo mode (SAVE MONEY)
stop_demo() {
    log_warn "Stopping demo mode (this will save money)..."
    
    # Scale down node groups
    eksctl scale nodegroup --cluster="$CLUSTER_NAME" --name=core --nodes=0 --region "$REGION" 2>/dev/null || true
    
    # Delete pods (stops Fargate billing)
    for ns in kafka monitoring argocd crossplane-system control-tower agents default; do
        log_info "Scaling down $ns..."
        kubectl scale deployment --all --replicas=0 -n "$ns" 2>/dev/null || true
    done
    
    log_success "Demo stopped! You are now saving ~\$20-30/month"
    log_info "Run './start-demo.sh' to resume"
}

# Show status
show_status() {
    log_info "Cluster: $CLUSTER_NAME"
    aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' 2>/dev/null || echo "Not running"
    echo ""
    log_info "Running pods:"
    kubectl get pods -A 2>/dev/null || echo "Cannot connect"
    echo ""
    log_info "Cost estimate: ~\$20-30/month when running, ~\$0 when stopped"
}

# Delete cluster
delete_cluster() {
    log_warn "WARNING: This will delete the entire cluster!"
    read -p "Type 'yes' to confirm: " confirm
    [ "$confirm" = "yes" ] || exit 1
    
    log_info "Deleting cluster..."
    eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION"
    log_success "Cluster deleted!"
}

# Main
case "${1:-}" in
    create)
        check_prereq
        create_cluster
        configure_kubectl
        ;;
    configure)
        check_prereq
        configure_kubectl
        ;;
    install)
        check_prereq
        install_kafka
        install_argocd
        install_crossplane
        install_monitoring
        ;;
    start)
        check_prereq
        start_demo
        ;;
    stop)
        check_prereq
        stop_demo
        ;;
    status)
        check_prereq
        show_status
        ;;
    delete)
        check_prereq
        delete_cluster
        ;;
    *)
        echo "Usage: $0 {create|configure|install|start|stop|status|delete}"
        echo ""
        echo "Commands:"
        echo "  create     - Create EKS Fargate cluster"
        echo "  configure - Configure kubectl"
        echo "  install   - Install Kafka, ArgoCD, Crossplane, Monitoring"
        echo "  start     - Start demo mode (run workloads)"
        echo "  stop      - Stop demo mode (SAVE MONEY)"
        echo "  status    - Show cluster status"
        echo "  delete    - Delete cluster"
        ;;
esac
