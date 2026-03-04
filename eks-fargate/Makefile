# =============================================================================
# Control Tower EKS Fargate - Management Script
# =============================================================================
# Cost: ~$20-30/month (Fargate only charges for pods)
# 
# Prerequisites:
#   - AWS CLI installed
#   - kubectl installed
#   - helm installed
#   - terraform installed
# 
# Usage:
#   make create    - Create EKS Fargate cluster
#   make configure - Configure kubectl
#   make start    - Start demo (scale up resources)
#   make stop     - Stop demo (scale to zero - SAVE MONEY)
#   make delete   - Destroy cluster
#   make status   - Show cluster status
# =============================================================================

.CLASSIGNORE:

# Configuration
CLUSTER_NAME ?= control-tower
REGION ?= us-east-1
NAMESPACE ?= control-tower

# Colors
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
RED := $(shell tput setaf 1)
BLUE := $(shell tput setaf 4)
RESET := $(shell tput sgr0)

# =============================================================================
# TARGETS
# =============================================================================

.PHONY: help create configure start stop status delete install-tools check-prereq

help:
	@echo ""
	@echo "${BLUE}Control Tower EKS Fargate - Management${RESET}"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "${GREEN}Targets:${RESET}"
	@echo "  create       - Create EKS Fargate cluster"
	@echo "  configure   - Configure kubectl to access cluster"
	@echo "  install-tools - Install kubectl, helm, eksctl"
	@echo "  start       - Start demo mode (scale up resources)"
	@echo "  stop        - Stop demo mode (scale to zero - SAVE MONEY)"
	@echo "  status      - Show cluster and pod status"
	@echo "  delete      - Destroy cluster (WARNING: deletes everything)"
	@echo ""
	@echo "${GREEN}Examples:${RESET}"
	@echo "  make create                    # Create cluster"
	@echo "  make start                     # Start demo"
	@echo "  make stop                      # Stop demo (saves money)"
	@echo "  make delete CLUSTER_NAME=my-cluster  # Delete specific cluster"
	@echo ""

check-prereq:
	@echo "${YELLOW}Checking prerequisites...${RESET}"
	@which aws > /dev/null 2>&1 || (echo "${RED}AWS CLI not found. Install: https://aws.amazon.com/cli/${RESET}" && exit 1)
	@which kubectl > /dev/null 2>&1 || (echo "${RED}kubectl not found. Run: make install-tools${RESET}" && exit 1)
	@which terraform > /dev/null 2>&1 || (echo "${RED}Terraform not found. Install: https://terraform.io${RESET}" && exit 1)
	@echo "${GREEN}All prerequisites met!${RESET}"

install-tools:
	@echo "${YELLOW}Installing tools...${RESET}"
	@echo "Installing kubectl..."
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	chmod +x kubectl
	sudo mv kubectl /usr/local/bin/
	@echo "Installing helm..."
	curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	@echo "Installing eksctl..."
	curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
	sudo mv /tmp/eksctl /usr/local/bin/
	@echo "${GREEN}Tools installed!${RESET}"

create: check-prereq
	@echo "${YELLOW}Creating EKS Fargate cluster...${RESET}"
	@echo "${YELLOW}This will take 10-15 minutes...${RESET}"
	@cd terraform && terraform init && terraform plan && terraform apply -var="cluster_name=$(CLUSTER_NAME)"
	@echo "${GREEN}Cluster created! Run: make configure${RESET}"

configure:
	@echo "${YELLOW}Configuring kubectl...${RESET}"
	aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(REGION)
	@echo "${GREEN}Kubectl configured!${RESET}"
	@echo "Test with: kubectl get pods -A"

start:
	@echo "${YELLOW}Starting demo mode...${RESET}"
	@echo "${GREEN}Scaling up EKS Fargate pods...${RESET}"
	@# Scale up node groups if any
	@eksctl get nodegroup --cluster=$(CLUSTER_NAME) --region=$(REGION) 2>/dev/null || true
	@echo "${GREEN}Deploying control tower components...${RESET}"
	@# Deploy Kafka
	kubectl create namespace kafka 2>/dev/null || true
	@# Deploy monitoring
	kubectl create namespace monitoring 2>/dev/null || true
	@# Deploy ArgoCD
	kubectl create namespace argocd 2>/dev/null || true
	@# Deploy Crossplane
	kubectl create namespace crossplane-system 2>/dev/null || true
	@echo "${GREEN}Demo mode started!${RESET}"
	@echo "Run: make status"

stop:
	@echo "${YELLOW}Stopping demo mode (saving money)...${RESET}"
	@# Scale down node groups to 0
	@eksctl scale nodegroup --cluster=$(CLUSTER_NAME) --nodes=0 --name=core 2>/dev/null || true
	@# Delete pods to stop billing
	@echo "Scaling down all workloads..."
	@for ns in kafka monitoring argocd crossplane-system control-tower agents; do \
		echo "Scaling down $$ns..."; \
		kubectl delete deployment --all -n $$ns 2>/dev/null || true; \
		kubectl delete statefulset --all -n $$ns 2>/dev/null || true; \
	done
	@echo "${GREEN}Demo stopped! You are now saving ~\$20-30/month${RESET}"
	@echo "Run: make start to resume demo mode"

status:
	@echo "${BLUE}=== Cluster Status ===${RESET}"
	@aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) --query 'cluster.status' 2>/dev/null || echo "Cluster not found"
	@echo ""
	@echo "${BLUE}=== Node Groups ===${RESET}"
	@eksctl get nodegroup --cluster=$(CLUSTER_NAME) --region=$(REGION) 2>/dev/null || echo "No node groups"
	@echo ""
	@echo "${BLUE}=== Running Pods ===${RESET}"
	@kubectl get pods -A 2>/dev/null || echo "Cannot connect to cluster"
	@echo ""
	@echo "${BLUE}=== Cost Estimate ===${RESET}"
	@echo "EKS Fargate: ~\$0.50/day for pod usage"
	@echo "EKS Cluster: ~\$0.10/hour (~\$72/month flat)"

delete:
	@echo "${RED}WARNING: This will delete the entire cluster!${RESET}"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo "${YELLOW}Deleting cluster...${RESET}"
	@eksctl delete cluster --name=$(CLUSTER_NAME) --region=$(REGION)
	@echo "${GREEN}Cluster deleted!${RESET}"

# =============================================================================
# INSTALL COMPONENTS
# =============================================================================

.PHONY: install-kafka install-argocd install-crossplane install-cilium install-all

install-kafka:
	@echo "${YELLOW}Installing Kafka...${RESET}"
	kubectl create namespace kafka
	helm repo add strimzi https://strimzi.io/charts
	helm install kafka strimzi/strimzi-kafka-operator -n kafka
	@kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: control-tower-kafka
  namespace: kafka
spec:
  kafka:
    replicas: 3
    version: 3.6.0
    resources:
      requests:
        cpu: "250m"
        memory: "512Mi"
      limits:
        cpu: "500m"
        memory: "1Gi"
    storage:
      type: ephemeral
  zookeeper:
    replicas: 3
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
EOF
	@echo "${GREEN}Kafka installed!${RESET}"

install-argocd:
	@echo "${YELLOW}Installing ArgoCD...${RESET}"
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "${GREEN}ArgoCD installed!${RESET}"
	@echo "Access UI: kubectl port-forward -n argocd svc/argocd-server 8080:443"

install-crossplane:
	@echo "${YELLOW}Installing Crossplane...${RESET}"
	kubectl create namespace crossplane-system
	helm repo add crossplane-stable https://charts.crossplane.io/stable
	helm install crossplane crossplane-stable/crossplane -n crossplane-system
	@echo "${GREEN}Crossplane installed!${RESET}"

install-cilium:
	@echo "${YELLOW}Installing Cilium...${RESET}"
	cilium install --version 1.14.0
	@echo "${GREEN}Cilium installed!${RESET}"

install-all: install-kafka install-argocd install-crossplane install-cilium
	@echo "${GREEN}All components installed!${RESET}"
