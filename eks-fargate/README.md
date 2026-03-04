# EKS Fargate Control Tower

Quick-start scripts for deploying the Control Tower on AWS EKS Fargate.

## Why EKS Fargate?

| Feature | EKS Fargate | EKS EC2 |
|---------|-------------|----------|
| **Monthly Cost** | ~$20-30 | ~$100+ |
| **Node Management** | None | Manual |
| **Auto-scaling** | Built-in | Karpenter needed |
| **Pay for usage** | Per pod | Per instance |

## Quick Start

### 1. Install Prerequisites

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/
```

### 2. Configure AWS

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Region: us-east-1
# Output format: json
```

### 3. Create Cluster

```bash
chmod +x quickstart.sh
./quickstart.sh create
```

This creates:
- EKS Fargate cluster
- VPC with public/private subnets
- Fargate profiles for all namespaces

### 4. Install Components

```bash
./quickstart.sh install
```

This installs:
- Kafka (Strimzi)
- ArgoCD
- Crossplane
- Prometheus + Grafana

### 5. Start Demo

```bash
./quickstart.sh start
```

### 6. Stop Demo (Save Money)

```bash
./quickstart.sh stop
```

---

## Cost Management

### When Running (Demo Mode)
- EKS Fargate: ~$20-30/month
- Pods: Pay per pod usage

### When Stopped
- EKS Cluster: ~$0 (no nodes, no pods)
- Total: ~$0/month

### Cost Optimization Tips

1. **Always stop after demo** - Run `./quickstart.sh stop`
2. **Use Spot instances** - For production, add managed node groups with spot
3. **Set TTL** - Auto-delete resources after X hours

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `./quickstart.sh create` | Create EKS Fargate cluster |
| `./quickstart.sh configure` | Configure kubectl |
| `./quickstart.sh install` | Install all components |
| `./quickstart.sh start` | Start demo (scale up) |
| `./quickstart.sh stop` | Stop demo (scale to zero) |
| `./quickstart.sh status` | Show status |
| `./quickstart.sh delete` | Delete cluster |

---

## Manual Commands

### Kubectl Examples

```bash
# Get all pods
kubectl get pods -A

# Get services
kubectl get svc -A

# View pods in kafka namespace
kubectl get pods -n kafka

# View logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# Port forward to ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### Helm Examples

```bash
# List helm releases
helm list -A

# Upgrade a release
helm upgrade kafka strimzi/strimzi-kafka-operator -n kafka

# Delete a release
helm uninstall prometheus -n monitoring
```

---

## Troubleshooting

### Cluster not found
```bash
aws eks list-clusters
```

### Can't connect to cluster
```bash
aws eks update-kubeconfig --name control-tower --region us-east-1
```

### Pods not starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Check Fargate status
```bash
aws eks describe-fargate-profile --cluster-name control-tower --region us-east-1 --fargate-profile-name default
```

---

## Monthly Cost Breakdown

| Component | Running | Stopped |
|-----------|---------|---------|
| EKS Cluster | $0 | $0 |
| Fargate Pods | ~$20-30 | $0 |
| EBS Storage | ~$5 | $0 |
| Data Transfer | ~$5 | $0 |
| **Total** | **~$30-40/mo** | **~$0** |

---

## Cleanup

To delete everything:

```bash
./quickstart.sh delete
```

Or manually:

```bash
eksctl delete cluster --name control-tower --region us-east-1
```
