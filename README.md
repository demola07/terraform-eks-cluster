# Production-Ready EKS Cluster on AWS

A Terraform-based infrastructure-as-code project for deploying a production-ready Amazon EKS (Elastic Kubernetes Service) cluster with secure bastion host access, high availability, and best practices for security and scalability.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Accessing the EKS Cluster](#accessing-the-eks-cluster)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Security](#security)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project deploys a complete EKS infrastructure including:
- **EKS Cluster** (v1.33) with managed node groups
- **High-availability VPC** across 2 availability zones
- **Secure bastion host** with SSM-only access (no SSH keys required)
- **Essential cluster add-ons**: CoreDNS, VPC-CNI, kube-proxy, EBS CSI driver
- **IAM roles with least privilege** using IRSA (IAM Roles for Service Accounts)
- **Encrypted storage** and comprehensive logging

**Module Version**: terraform-aws-modules/eks/aws v21.10.1

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Region (us-east-1)                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.16.0.0/16)                     │ │
│  │                                                           │ │
│  │  ┌─────────────────────┐    ┌─────────────────────┐     │ │
│  │  │   AZ 1 (us-east-1a) │    │   AZ 2 (us-east-1b) │     │ │
│  │  │                     │    │                     │     │ │
│  │  │  Public Subnet      │    │  Public Subnet      │     │ │
│  │  │  ┌──────────────┐   │    │  ┌──────────────┐   │     │ │
│  │  │  │ NAT Gateway  │   │    │  │ NAT Gateway  │   │     │ │
│  │  │  │ Bastion Host │   │    │  │              │   │     │ │
│  │  │  └──────────────┘   │    │  └──────────────┘   │     │ │
│  │  │                     │    │                     │     │ │
│  │  │  Private Subnet     │    │  Private Subnet     │     │ │
│  │  │  ┌──────────────┐   │    │  ┌──────────────┐   │     │ │
│  │  │  │ EKS Worker   │   │    │  │ EKS Worker   │   │     │ │
│  │  │  │ Nodes        │   │    │  │ Nodes        │   │     │ │
│  │  │  └──────────────┘   │    │  └──────────────┘   │     │ │
│  │  └─────────────────────┘    └─────────────────────┘     │ │
│  │                                                           │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │           EKS Control Plane (Managed by AWS)        │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Access Flow**:
```
Your Laptop → AWS SSM → Bastion Host → EKS API → Worker Nodes → Pods
```

---

## ✨ Features

### Infrastructure
- ✅ **EKS Cluster v1.33** with modern authentication (API_AND_CONFIG_MAP)
- ✅ **High-availability VPC** with 2 AZs, 2 public subnets, 2 private subnets
- ✅ **Dual NAT Gateways** for redundancy
- ✅ **Managed node groups** with on-demand instances (t3.medium)
- ✅ **Auto-scaling** support (min: 1, max: 3, desired: 1)

### Security
- ✅ **Bastion host** with SSM Session Manager (no SSH keys needed)
- ✅ **IAM roles** with least privilege principle
- ✅ **IRSA enabled** for pod-level AWS permissions
- ✅ **Encrypted EBS volumes** for all nodes
- ✅ **Private subnets** for worker nodes
- ✅ **Security groups** with minimal required access
- ✅ **Cluster logging** enabled (API, audit, authenticator)

### Add-ons
- ✅ **CoreDNS** - DNS resolution for services
- ✅ **VPC-CNI** - Pod networking
- ✅ **kube-proxy** - Network proxy
- ✅ **EBS CSI Driver** - Persistent volume support

### Tools (Pre-installed on Bastion)
- ✅ **kubectl** - Kubernetes CLI
- ✅ **helm** - Package manager for Kubernetes
- ✅ **k9s** - Terminal UI for Kubernetes
- ✅ **AWS CLI v2** - AWS command-line interface

---

## 📦 Prerequisites

### Required Tools
- **Terraform** >= 1.5.7
- **AWS CLI** >= 2.0
- **AWS Account** with appropriate permissions

### AWS Provider Requirements
- **AWS Provider** >= 6.23.0
- **Time Provider** >= 0.9
- **TLS Provider** >= 4.0

### AWS Permissions
Your IAM user/role needs permissions to create:
- VPC, Subnets, Route Tables, Internet Gateway, NAT Gateway
- EKS Cluster, Node Groups, Add-ons
- EC2 Instances (bastion), Security Groups
- IAM Roles, Policies, Instance Profiles
- CloudWatch Log Groups
- KMS Keys (for encryption)

---

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <your-repo-url>
cd eks

# Navigate to the deployment directory
cd eks
```

### 2. Create Your Variables File

```bash
# Copy the example file
cp dev-official.tfvars.example dev-official.tfvars

# Edit with your values
vim dev-official.tfvars
```

**Minimum required variables**:
```hcl
env                        = "dev"
aws-region                 = "us-east-1"
cluster-name               = "daas-eks"
vpc-cidr-block             = "10.16.0.0/16"
cluster-version            = "1.33"
ondemand_instance_types    = ["t3.medium"]
desired_capacity_on_demand = 1
min_capacity_on_demand     = 1
max_capacity_on_demand     = 3
enable_bastion             = true
bastion_instance_type      = "t3.micro"
bastion_enable_ssh         = false
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=dev-official.tfvars

# Deploy the infrastructure
terraform apply -var-file=dev-official.tfvars
```

**Deployment time**: ~15-20 minutes

### 4. Verify Deployment

```bash
# Get cluster information
terraform output

# Expected outputs:
# - cluster_name
# - cluster_endpoint
# - bastion_instance_id
# - bastion_ssm_command
```

---

## 🔐 Accessing the EKS Cluster

### Method 1: Via Bastion Host (Recommended)

The bastion host is pre-configured with kubectl, helm, and k9s. Access is secured via AWS Systems Manager (SSM) - no SSH keys required.

#### Step 1: Get Bastion Instance ID

```bash
# From your local machine
cd /Users/ademolaadesina/projects/eks/eks

# Get the instance ID
BASTION_ID=$(terraform output -raw bastion_instance_id)
echo $BASTION_ID
```

#### Step 2: Connect to Bastion via SSM

```bash
# Connect using AWS SSM Session Manager
aws ssm start-session --target $BASTION_ID --region us-east-1

# You should see a shell prompt like:
# sh-5.2$
```

**Alternative**: Get the full command from Terraform output:
```bash
terraform output bastion_ssm_command
# Copy and run the command shown
```

#### Step 3: Verify kubectl Access

Once connected to the bastion:

```bash
# Check nodes
kubectl get nodes

# Expected output:
# NAME                            STATUS   ROLES    AGE   VERSION
# ip-10-16-139-137.ec2.internal   Ready    <none>   55m   v1.33.5-eks-113cf36

# Check all pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

#### Step 4: Use Pre-installed Tools

```bash
# Use kubectl (alias 'k' is available)
k get pods -A

# Launch K9s terminal UI
k9s

# Use helm
helm list -A

# Check AWS CLI
aws eks describe-cluster --name dev-daas-eks --region us-east-1
```

### Method 2: From Your Local Machine

If you want to access the cluster directly from your laptop:

#### Step 1: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name dev-daas-eks

# Verify access
kubectl get nodes
```

**Note**: This requires:
- Your IAM user/role to have EKS access permissions
- The cluster's public endpoint to be enabled (`endpoint-public-access = true`)
- Your IP to be allowed in the cluster's public access CIDRs

---

## 📁 Project Structure

```
eks/
├── eks/                          # Root module (deployment)
│   ├── main.tf                   # Main configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── backend.tf                # Provider and backend config
│   └── dev-official.tfvars       # Your environment variables (gitignored)
│
├── module/                       # EKS module (reusable)
│   ├── eks-cluster.tf            # EKS cluster configuration
│   ├── eks-node-groups.tf        # Node group definitions
│   ├── vpc.tf                    # VPC and networking
│   ├── bastion.tf                # Bastion host configuration
│   ├── bastion-userdata.sh       # Bastion initialization script
│   ├── bastion-outputs.tf        # Bastion outputs
│   ├── iam-irsa.tf               # IRSA roles (EBS CSI, etc.)
│   ├── outputs.tf                # Module outputs
│   └── variables.tf              # Module variables
│
├── SECURITY-GUIDE.md             # Security architecture documentation
├── QUICK-COMMANDS.md             # Quick reference commands
└── README.md                     # This file
```

---

## ⚙️ Configuration

### Key Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `cluster-name` | EKS cluster name | - | Yes |
| `cluster-version` | Kubernetes version | `1.33` | Yes |
| `vpc-cidr-block` | VPC CIDR range | `10.16.0.0/16` | Yes |
| `ondemand_instance_types` | Instance types for nodes | `["t3.medium"]` | Yes |
| `desired_capacity_on_demand` | Desired number of nodes | `1` | Yes |
| `enable_bastion` | Enable bastion host | `true` | No |
| `bastion_instance_type` | Bastion instance type | `t3.micro` | No |
| `endpoint-public-access` | Enable public API endpoint | `true` | No |
| `endpoint-private-access` | Enable private API endpoint | `true` | No |

### Customizing Node Groups

Edit `module/eks-node-groups.tf`:

```hcl
locals {
  node_groups = {
    ondemand = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      min_size     = 1
      max_size     = 5      # Increase for more scaling
      desired_size = 2      # Start with 2 nodes
      
      # Customize disk size
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100  # Increase to 100GB
            volume_type = "gp3"
            encrypted   = true
          }
        }
      }
    }
  }
}
```

### Adding More IRSA Roles

Edit `module/iam-irsa.tf` to add roles for other services:

```hcl
# Example: AWS Load Balancer Controller
module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster-name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

---

## 🔒 Security

### Network Security

- **Private Subnets**: Worker nodes run in private subnets with no direct internet access
- **NAT Gateways**: Outbound internet access via NAT gateways in public subnets
- **Security Groups**: Minimal required access between components
- **Bastion Access**: Only via SSM (port 443), no SSH port 22 exposed

### IAM Security

- **Cluster Creator Admin**: Automatically granted admin access via access entry
- **Bastion Role**: Limited to EKS describe/access permissions
- **Node Role**: Standard EKS worker node permissions
- **IRSA**: Pod-level permissions (e.g., EBS CSI driver can only manage volumes)

### Encryption

- **EBS Volumes**: All node volumes encrypted with AWS-managed keys
- **Secrets**: Kubernetes secrets encrypted at rest (optional KMS key)
- **Logs**: CloudWatch logs encrypted

### Access Control

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Network (Security Groups)                     │
│   ✓ Bastion → EKS API (port 443)                       │
│   ✓ Nodes → EKS API (port 443)                         │
├─────────────────────────────────────────────────────────┤
│ Layer 2: IAM Authentication                            │
│   ✓ Bastion IAM role                                   │
│   ✓ Your IAM user/role                                 │
├─────────────────────────────────────────────────────────┤
│ Layer 3: EKS Access Entries (Kubernetes RBAC)          │
│   ✓ Cluster creator → Admin                            │
│   ✓ Bastion role → Admin                               │
└─────────────────────────────────────────────────────────┘
```

**For detailed security architecture**, see [SECURITY-GUIDE.md](SECURITY-GUIDE.md)

---

## 🛠️ Maintenance

### Updating the Cluster

```bash
# After modifying tfvars or module code
terraform plan -var-file=dev-official.tfvars
terraform apply -var-file=dev-official.tfvars
```

### Upgrading Kubernetes Version

1. Update `cluster-version` in your tfvars:
```hcl
cluster-version = "1.34"  # New version
```

2. Apply the change:
```bash
terraform apply -var-file=dev-official.tfvars
```

3. Node groups will automatically update with rolling deployment

### Scaling Node Groups

**Via Terraform**:
```hcl
# In dev-official.tfvars
desired_capacity_on_demand = 3
min_capacity_on_demand     = 2
max_capacity_on_demand     = 5
```

**Via AWS CLI**:
```bash
aws eks update-nodegroup-config \
  --cluster-name dev-daas-eks \
  --nodegroup-name dev-daas-eks-od \
  --scaling-config minSize=2,maxSize=5,desiredSize=3
```

### Stopping/Starting Bastion (Cost Savings)

```bash
# Stop bastion when not in use
aws ec2 stop-instances --instance-ids $BASTION_ID

# Start when needed
aws ec2 start-instances --instance-ids $BASTION_ID
```

### Viewing Logs

```bash
# Cluster logs (CloudWatch)
aws logs tail /aws/eks/dev-daas-eks/cluster --follow

# Bastion setup logs (from bastion)
sudo cat /var/log/bastion-setup.log
sudo cat /var/log/cloud-init-output.log
```

---

## 🐛 Troubleshooting

### Issue: Cannot connect to bastion via SSM

**Symptoms**: `aws ssm start-session` fails

**Solutions**:
```bash
# 1. Verify bastion is running
aws ec2 describe-instances --instance-ids $BASTION_ID \
  --query 'Reservations[0].Instances[0].State.Name'

# 2. Check SSM agent status
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$BASTION_ID"

# 3. Verify IAM role is attached
aws ec2 describe-instances --instance-ids $BASTION_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

### Issue: kubectl commands timeout from bastion

**Symptoms**: `dial tcp 10.16.x.x:443: i/o timeout`

**Solutions**:
```bash
# 1. Verify security group rules exist
terraform plan -var-file=dev-official.tfvars
# Look for bastion_to_cluster security group rule

# 2. Check EKS endpoint configuration
aws eks describe-cluster --name dev-daas-eks \
  --query 'cluster.resourcesVpcConfig'

# 3. Re-apply Terraform to fix security groups
terraform apply -var-file=dev-official.tfvars
```

### Issue: kubectl authentication error

**Symptoms**: `error: You must be logged in to the server`

**Solutions**:
```bash
# From bastion, reconfigure kubeconfig
aws eks update-kubeconfig --region us-east-1 --name dev-daas-eks

# Verify IAM role has access entry
aws eks list-access-entries --cluster-name dev-daas-eks
```

### Issue: Nodes not joining cluster

**Symptoms**: No nodes shown in `kubectl get nodes`

**Solutions**:
```bash
# 1. Check node group status
aws eks describe-nodegroup \
  --cluster-name dev-daas-eks \
  --nodegroup-name dev-daas-eks-od

# 2. Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --filters "Name=tag:Name,Values=dev-daas-eks-od"

# 3. Check node IAM role
aws iam get-role --role-name <node-role-name>
```

### Issue: Terraform state locked

**Symptoms**: `Error acquiring the state lock`

**Solutions**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### Common kubectl Commands for Debugging

```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl get pods -A -o wide

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

---

## 📊 Resource Summary

After deployment, you'll have:

| Resource Type | Count | Purpose |
|---------------|-------|---------|
| VPC | 1 | Network isolation |
| Subnets | 4 | 2 public, 2 private |
| NAT Gateways | 2 | High availability |
| Internet Gateway | 1 | Public internet access |
| EKS Cluster | 1 | Kubernetes control plane |
| Node Groups | 1 | Worker nodes |
| EC2 Instances | 1-3 | Worker nodes (auto-scaled) |
| Bastion Host | 1 | Secure access point |
| Security Groups | 3 | Network security |
| IAM Roles | 4+ | Access control |
| CloudWatch Log Groups | 1 | Cluster logging |

**Estimated Monthly Cost** (us-east-1):
- EKS Cluster: ~$73/month
- EC2 Instances (1x t3.medium): ~$30/month
- NAT Gateways (2x): ~$65/month
- Bastion (t3.micro): ~$7.5/month
- **Total**: ~$175-200/month

---

## 🤝 Contributing

To modify this infrastructure:

1. Make changes to the relevant `.tf` files
2. Test with `terraform plan`
3. Apply with `terraform apply`
4. Update this README if adding new features
5. Commit changes to version control

---

## 📚 Additional Documentation

- **[SECURITY-GUIDE.md](SECURITY-GUIDE.md)** - Detailed security architecture, IAM roles, and network flow
- **[QUICK-COMMANDS.md](QUICK-COMMANDS.md)** - Quick reference for common commands
- **[Official EKS Module Docs](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/21.10.1)** - Terraform module documentation
- **[AWS EKS Documentation](https://docs.aws.amazon.com/eks/)** - AWS official documentation

---

## 📝 License

This project is licensed under the MIT License.

---

## 🆘 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review the [SECURITY-GUIDE.md](SECURITY-GUIDE.md)
3. Check Terraform and AWS documentation
4. Open an issue in the repository

---

**Built with ❤️ using Terraform and AWS EKS**
