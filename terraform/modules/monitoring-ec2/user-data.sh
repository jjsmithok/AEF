#!/bin/bash
# Monitoring EC2 User Data Script
# Bootstrap: Install Docker, Docker Compose, clone monitoring repo

set -e

echo "=== Monitoring EC2 Bootstrap Started ==="
echo "Timestamp: $(date -Iseconds)"

# Update and install prerequisites
echo "=== Installing prerequisites ==="
apt-get update -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    awscli \
    wget

# Add Docker GPG key and repository (ARM64)
echo "=== Installing Docker ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install SSM Agent (for Session Manager - no SSH needed)
echo "=== Installing SSM Agent ==="
cd /tmp
if [ "$(uname -m)" = "aarch64" ]; then
    wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_arm64/amazon-ssm-agent.deb
else
    wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
fi
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create monitoring directory
mkdir -p /opt/monitoring
cd /opt/monitoring

# Clone monitoring repo (if provided)
%{ if github_repo_url != "" }
echo "=== Cloning monitoring repo ==="
git clone ${github_repo_url} /opt/monitoring
cd /opt/monitoring
git config --global --add safe.directory /opt/monitoring
%{ else }
# Create placeholder if no repo
echo "=== No repo provided, creating placeholder ==="
cat > docker-compose.yml << 'EOF'
# Placeholder - add your monitoring stack here
# See: https://grafana.com/docs/grafana/latest/installation/docker/
services:
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SERVER_ROOT_URL=https://monitoring.example.com

volumes:
  grafana-data:
EOF
%{ endif }

# Create systemd timer for git pull (optional - for zero-touch updates)
echo "=== Setting up git-pull timer ==="
cat > /etc/systemd/system/monitoring-git-pull.service << 'EOF'
[Unit]
Description=Git pull and restart monitoring services

[Service]
Type=oneshot
WorkingDirectory=/opt/monitoring
ExecStart=/usr/bin/git pull origin main
ExecStart=/usr/bin/docker compose up -d
EOF

cat > /etc/systemd/system/monitoring-git-pull.timer << 'EOF'
[Unit]
Description=Periodic git pull for monitoring updates

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=monitoring-git-pull.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable monitoring-git-pull.timer

# Start docker-compose
echo "=== Starting monitoring stack ==="
docker compose up -d

echo "=== Bootstrap Complete ==="
echo "Services status:"
docker compose ps

echo "Ports:"
echo "  Grafana:    3000"
echo "  Prometheus: 9090"
echo "  Loki:       3100"
echo "  OTEL:       4317/4318"

# Final message
echo "=== Ready for monitoring ==="
