#!/bin/bash
# Exit on error, but log failures
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/bastion-setup.log
}

log "Starting bastion setup..."

# Update system
log "Updating system packages..."
dnf update -y || log "WARNING: System update had issues, continuing..."

# Install required tools
# Note: curl-minimal is already installed, so we skip curl to avoid conflicts
log "Installing required tools..."
dnf install -y \
    git \
    wget \
    unzip \
    jq \
    vim \
    tmux || log "WARNING: Some tools failed to install, continuing..."

# Install AWS CLI v2
log "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || log "WARNING: Failed to download AWS CLI"
unzip awscliv2.zip || log "WARNING: Failed to unzip AWS CLI"
./aws/install || log "WARNING: Failed to install AWS CLI"
rm -rf aws awscliv2.zip

# Install kubectl
log "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || log "WARNING: Failed to download kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/ || log "WARNING: Failed to move kubectl"

# Install helm
log "Installing helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || log "WARNING: Failed to install helm"

# Install k9s (Kubernetes CLI UI)
log "Installing k9s..."
curl -sS https://webinstall.dev/k9s | bash || log "WARNING: Failed to install k9s"
if [ -f ~/.local/bin/k9s ]; then
    mv ~/.local/bin/k9s /usr/local/bin/ || log "WARNING: Failed to move k9s"
fi

# Configure kubectl for EKS
log "Configuring kubectl for EKS cluster..."
mkdir -p /home/ec2-user/.kube
aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name} --kubeconfig /home/ec2-user/.kube/config || log "WARNING: Failed to configure kubectl for ec2-user"
chown -R ec2-user:ec2-user /home/ec2-user/.kube

# Also configure for ssm-user (for SSM sessions)
log "Configuring kubectl for ssm-user..."
mkdir -p /home/ssm-user/.kube
aws eks update-kubeconfig --region ${aws_region} --name ${cluster_name} --kubeconfig /home/ssm-user/.kube/config || log "WARNING: Failed to configure kubectl for ssm-user"
chown -R ssm-user:ssm-user /home/ssm-user/.kube

# Add helpful aliases
cat >> /home/ec2-user/.bashrc <<'EOF'

# Kubernetes aliases
alias k='kubectl'

# EKS cluster info
export CLUSTER_NAME=${cluster_name}
export AWS_REGION=${aws_region}

# Helpful prompt
export PS1='\[\033[01;32m\]\u@bastion\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "==================================="
echo "EKS Bastion Host"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "==================================="
echo ""
echo "Quick commands:"
echo "  k get nodes          - List cluster nodes"
echo "  k get pods -A        - List all pods"
echo "  k9s                  - Launch K9s UI"
echo "  helm list -A         - List Helm releases"
echo ""
EOF

# Create welcome message
cat > /etc/motd <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              EKS Bastion/Jump Box                        ║
║                                                           ║
║  This server provides secure access to the EKS cluster   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Available tools:
  - kubectl (k)
  - helm
  - k9s
  - aws cli
  - git

Run 'kubectl get nodes' to verify cluster access
EOF

# Enable and start SSM agent (for Session Manager access)
log "Enabling SSM agent..."
systemctl enable amazon-ssm-agent || log "WARNING: Failed to enable SSM agent"
systemctl start amazon-ssm-agent || log "WARNING: Failed to start SSM agent"

log "Bastion setup complete!"
log "Setup log saved to /var/log/bastion-setup.log"
echo "Bastion setup complete! Check /var/log/bastion-setup.log for details."
