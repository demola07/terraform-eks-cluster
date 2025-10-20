# Production EKS Cluster with Terraform

Production-ready Amazon EKS cluster using official Terraform modules with secure bastion access.

## 🎯 Features

- ✅ **High Availability**: Multi-AZ deployment with 3 NAT Gateways
- ✅ **Secure Access**: Bastion host with SSM (no SSH keys needed)
- ✅ **Auto-Managed Add-ons**: vpc-cni, CoreDNS, kube-proxy, EBS CSI driver
- ✅ **Production Ready**: Encrypted volumes, cluster logging, IRSA enabled
- ✅ **Official Modules**: Using terraform-aws-modules (battle-tested)

## 📁 Project Structure

```
eks/
├── module/                 
│   ├── vpc.tf             # VPC with HA NAT gateways
│   ├── eks-cluster.tf     # EKS cluster + add-ons
│   ├── eks-node-groups.tf # Worker nodes
│   ├── bastion.tf         # Jump box with SSM
│   └── iam-irsa.tf        # IAM roles for service accounts
├── eks/                   # Root configuration
│   ├── main.tf            # Module invocation
│   ├── backend.tf         # State backend
│   ├── variables-official.tf
│   └── dev-official.tfvars # Your configuration
├── README.md              # This file
└── QUICK-COMMANDS.md      # Command reference
```

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install tools (macOS)
brew install terraform awscli
brew install --cask session-manager-plugin

# Configure AWS
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1)
```

### 2. Deploy

```bash
cd eks/
terraform init
terraform apply -var-file=dev-official.tfvars
```

### 3. Access Cluster

```bash
# Get bastion instance ID
INSTANCE_ID=$(terraform output -raw bastion_instance_id)

# Connect via SSM (no SSH key needed!)
aws ssm start-session --target $INSTANCE_ID --region us-east-1

# Use kubectl (pre-configured on bastion)
kubectl get nodes
kubectl get pods -A
k9s  # Launch Kubernetes UI
```

## 📋 What Gets Created

### Infrastructure

**Networking:**
- 1 VPC (10.16.0.0/16)
- 6 Subnets (3 public, 3 private across 3 AZs)
- 3 NAT Gateways (HA - one per AZ)
- 1 Internet Gateway
- Route tables and security groups

**EKS Cluster:**
- Kubernetes 1.31
- Private + Public endpoints (public restricted to bastion IP)
- All control plane logging enabled
- IRSA (IAM Roles for Service Accounts) enabled

**Add-ons (Auto-managed):**
- vpc-cni (latest)
- coredns (latest)
- kube-proxy (latest)
- aws-ebs-csi-driver (latest with IRSA)

**Worker Nodes:**
- On-demand node group: 1-5 nodes (t3a.medium)
- Encrypted gp3 volumes (50GB)
- Auto Scaling enabled

**Bastion/Jump Box:**
- t3.micro instance in public subnet
- SSM access (default - no SSH keys)
- Pre-installed: kubectl, helm, k9s, AWS CLI
- Auto-configured for EKS cluster


## 🔐 Security Features

1. **Bastion Access Only**
   - EKS API endpoint restricted to bastion IP only
   - No direct internet access to cluster

2. **SSM Instead of SSH**
   - No SSH keys to manage
   - No open port 22
   - Full audit trail in CloudTrail
   - Session logging available

3. **Encrypted Everything**
   - EBS volumes encrypted
   - Secrets encryption (optional KMS)
   - TLS for all communications

4. **Private Worker Nodes**
   - Nodes in private subnets
   - Outbound internet via NAT gateways
   - No public IPs on nodes

5. **IRSA (IAM Roles for Service Accounts)**
   - Pods can assume IAM roles
   - No node-level permissions needed
   - Least privilege access

## ⚙️ Configuration

### Default Configuration (dev-official.tfvars)

```hcl
# Environment
env        = "dev"
aws-region = "us-east-1"

# Networking
vpc-cidr-block        = "10.16.0.0/16"
pub-cidr-block        = ["10.16.0.0/20", "10.16.16.0/20", "10.16.32.0/20"]
pri-cidr-block        = ["10.16.128.0/20", "10.16.144.0/20", "10.16.160.0/20"]
pub-availability-zone = ["us-east-1a", "us-east-1b", "us-east-1c"]
pri-availability-zone = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS
cluster-version         = "1.31"
cluster-name            = "eks-cluster"
endpoint-private-access = true
endpoint-public-access  = true  # Restricted to bastion IP

# Nodes
ondemand_instance_types    = ["t3a.medium"]
desired_capacity_on_demand = 1
min_capacity_on_demand     = 1
max_capacity_on_demand     = 5

# Bastion (SSM only - no SSH key needed)
enable_bastion     = true
bastion_enable_ssh = false  # SSM only (more secure)
```

### Enable SSH Access (Optional)

```hcl
# In dev-official.tfvars
bastion_enable_ssh    = true
bastion_key_name      = "my-key-pair"      # Your AWS key name
bastion_allowed_cidrs = ["1.2.3.4/32"]     # Your IP address
```

### Cost Optimization

1. **Single NAT (dev only)**: Save ~$65/month
   ```hcl
   # In module-official/vpc.tf
   single_nat_gateway = true
   ```

2. **Stop bastion when not in use**: Save ~$7/month
   ```bash
   aws ec2 stop-instances --instance-ids $INSTANCE_ID
   ```

3. **Use spot instances**: Save ~50% on compute
4. **Smaller instance types**: t3a.small instead of medium

## 🛠️ Common Tasks

### Deploy Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx

# Expose via load balancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get URL
kubectl get svc nginx
```

### Install Helm Chart

```bash
# Add repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install
helm install my-app bitnami/nginx

# List releases
helm list -A
```

### Scale Deployment

```bash
kubectl scale deployment nginx --replicas=3
```

### View Logs

```bash
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow
```

## 🔧 Troubleshooting

### Can't connect to bastion via SSM

```bash
# Check SSM agent
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID"

# Verify Session Manager plugin
session-manager-plugin --version
```

### kubectl not working on bastion

```bash
# SSH/SSM into bastion
aws ssm start-session --target $INSTANCE_ID

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name dev-daas-eks-cluster

# Test
kubectl get nodes
```

### Nodes not joining cluster

```bash
# Check node group
aws eks describe-nodegroup \
  --cluster-name dev-daas-eks-cluster \
  --nodegroup-name dev-daas-eks-cluster-ondemand-nodes

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(Tags[?Key==`eks:cluster-name`].Value, `dev-daas-eks-cluster`)]'
```

## 🧹 Cleanup

```bash
# Destroy everything
terraform destroy -var-file=dev-official.tfvars
# Type 'yes' when prompted
# ⏱️ Takes ~10-15 minutes
```

## 📚 Architecture

### Network Flow

```
Internet
    ↓
Internet Gateway
    ↓
Public Subnets (3 AZs)
    ├─ NAT Gateways (3)
    └─ Bastion Host
        ↓ (SSM/SSH)
        ↓
Private Subnets (3 AZs)
    ├─ EKS Control Plane
    └─ Worker Nodes
        ↓ (via NAT)
        ↓
Internet (for pulling images, etc.)
```

### Access Flow

```
Your Computer
    ↓ (AWS CLI + SSM)
AWS Systems Manager
    ↓ (Secure tunnel)
Bastion Host
    ↓ (kubectl - HTTPS to EKS API)
EKS Cluster
    ↓
Worker Nodes
```

## 📖 Additional Resources

- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Contributing

This is a personal project, but suggestions are welcome!

## 📄 License

MIT License - feel free to use for your own projects.

---

**Ready to deploy?** See [QUICK-COMMANDS.md](./QUICK-COMMANDS.md) for command reference.
