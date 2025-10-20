# EKS Security Architecture Guide

## Table of Contents
1. [IAM Roles & Permissions](#iam-roles--permissions)
2. [Security Groups](#security-groups)
3. [Network Flow](#network-flow)
4. [Access Control](#access-control)

---

## 1. IAM Roles & Permissions

### Overview: Three Types of IAM Roles

Your EKS cluster uses **three distinct IAM role types**, each serving a different purpose:

```
┌─────────────────────────────────────────────────────────────┐
│                    IAM Role Types                           │
├─────────────────────────────────────────────────────────────┤
│ 1. EKS Cluster Role      → Manages AWS resources            │
│ 2. Node Group Role       → Worker nodes permissions         │
│ 3. Bastion Role          → Jump box access                  │
│ 4. IRSA Roles            → Pod-level permissions            │
└─────────────────────────────────────────────────────────────┘
```

---

### 1.1 EKS Cluster Role (Managed by Official Module)

**Purpose**: Allows EKS control plane to manage AWS resources on your behalf.

**Created by**: `terraform-aws-modules/eks/aws` module automatically

**Permissions** (AWS Managed Policies):
- `AmazonEKSClusterPolicy` - Core EKS operations
- `AmazonEKSVPCResourceController` - ENI management for pods

**What it does**:
- Creates/deletes ENIs (Elastic Network Interfaces) for pods
- Manages load balancers for services
- Integrates with CloudWatch for logging
- Manages security groups for the cluster

**You don't need to create this** - the official EKS module handles it.

---

### 1.2 Node Group Role (Managed by Official Module)

**Purpose**: Gives worker nodes permissions to join the cluster and pull images.

**Created by**: `terraform-aws-modules/eks/aws` module automatically

**Permissions** (AWS Managed Policies):
- `AmazonEKSWorkerNodePolicy` - Allows nodes to connect to EKS
- `AmazonEKS_CNI_Policy` - VPC networking for pods
- `AmazonEC2ContainerRegistryReadOnly` - Pull images from ECR
- `AmazonSSMManagedInstanceCore` - SSM access (optional)

**What it does**:
- Registers nodes with the EKS cluster
- Assigns IP addresses to pods (VPC CNI)
- Pulls container images from ECR
- Sends logs to CloudWatch
- Allows SSM access to nodes (for debugging)

**You don't need to create this** - the official EKS module handles it.

---

### 1.3 Bastion Role (Custom - You Created This)

**Location**: `module/bastion.tf` lines 52-106

**Purpose**: Allows bastion host to access EKS cluster and use SSM.

**Trust Policy** (Who can assume this role):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"  ← Only EC2 instances can use this
    }
  }]
}
```

**Attached Policies**:

#### a) AWS Managed Policy: `AmazonEKSClusterPolicy`
```hcl
resource "aws_iam_role_policy_attachment" "bastion_eks_read" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```
- Allows reading EKS cluster information
- Needed for `aws eks update-kubeconfig` command

#### b) AWS Managed Policy: `AmazonSSMManagedInstanceCore`
```hcl
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```
- Enables SSM Session Manager access
- No SSH keys needed!
- Allows `aws ssm start-session` command

#### c) Custom Inline Policy: EKS Access
```hcl
resource "aws_iam_role_policy" "bastion_eks_access" {
  name = "${var.cluster-name}-bastion-eks-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",      # Get cluster details
        "eks:ListClusters",          # List all clusters
        "eks:DescribeNodegroup",     # Get node group info
        "eks:ListNodegroups",        # List node groups
        "eks:AccessKubernetesApi"    # Access K8s API via IAM
      ]
      Resource = "*"
    }]
  })
}
```

**Why these permissions?**
- `eks:DescribeCluster` → Needed for `aws eks update-kubeconfig`
- `eks:AccessKubernetesApi` → Allows kubectl commands via IAM authentication
- SSM policy → Secure access without SSH keys

---

### 1.4 IRSA Roles (IAM Roles for Service Accounts)

**Location**: `module/iam-irsa.tf`

**Purpose**: Give Kubernetes pods AWS permissions (not EC2 instances).

**Example: EBS CSI Driver Role**

```hcl
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster-name}-ebs-csi-driver"
  attach_ebs_csi_policy = true  # Allows creating/attaching EBS volumes
  
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
```

**How IRSA Works**:
```
┌──────────────────────────────────────────────────────────┐
│  Pod (ebs-csi-controller)                                │
│  ↓                                                        │
│  Service Account: ebs-csi-controller-sa                  │
│  ↓                                                        │
│  OIDC Token (proof of identity)                          │
│  ↓                                                        │
│  AWS STS (Security Token Service)                        │
│  ↓                                                        │
│  Temporary AWS Credentials                               │
│  ↓                                                        │
│  Can now create/attach EBS volumes!                      │
└──────────────────────────────────────────────────────────┘
```

**Why use IRSA?**
- ✅ Pod-level permissions (not node-level)
- ✅ Least privilege principle
- ✅ No AWS credentials stored in pods
- ✅ Automatic credential rotation

**Common IRSA Use Cases**:
- EBS CSI Driver (create volumes)
- AWS Load Balancer Controller (create ALB/NLB)
- External DNS (manage Route53 records)
- Cluster Autoscaler (scale node groups)
- S3 access from pods

---

## 2. Security Groups

### Overview: Three Security Groups

```
┌─────────────────────────────────────────────────────────────┐
│                  Security Group Architecture                │
├─────────────────────────────────────────────────────────────┤
│ 1. Bastion SG       → Controls bastion access               │
│ 2. Cluster SG       → EKS control plane security            │
│ 3. Node SG          → Worker node security                  │
└─────────────────────────────────────────────────────────────┘
```

---

### 2.1 Bastion Security Group

**Location**: `module/bastion.tf` lines 6-37

**Name**: `dev-daas-eks-bastion-sg`

**Inbound Rules** (Ingress):
```hcl
# SSH access (OPTIONAL - disabled by default)
dynamic "ingress" {
  for_each = var.bastion_enable_ssh ? [1] : []
  content {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs  # Your IP only
    description = "SSH access from allowed IPs"
  }
}
```
- **Port 22 (SSH)**: Only if `bastion_enable_ssh = true`
- **Source**: Your specific IP addresses only
- **Default**: Disabled (SSM is more secure)

**Outbound Rules** (Egress):
```hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"           # All protocols
  cidr_blocks = ["0.0.0.0/0"]  # Anywhere
  description = "Allow all outbound"
}
```
- **All traffic**: Bastion can reach internet, EKS API, etc.
- **Why?**: Needs to download kubectl, helm, k9s, and reach EKS API

---

### 2.2 EKS Cluster Security Group

**Created by**: Official EKS module automatically

**Name**: `eks-cluster-sg-dev-daas-eks-*`

**Purpose**: Controls access to EKS control plane (API server)

**Inbound Rules** (Managed by Terraform):

#### a) From Bastion (Custom Rule)
```hcl
resource "aws_security_group_rule" "bastion_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow bastion to access EKS cluster API"
}
```
- **Port 443 (HTTPS)**: EKS API endpoint
- **Source**: Bastion security group only
- **Why**: Allows `kubectl` commands from bastion

#### b) From Worker Nodes (Automatic)
- EKS module automatically allows nodes to reach control plane
- Port 443 for API calls
- Bidirectional communication

**Outbound Rules**:
- Allows control plane to reach worker nodes
- Port 443, 10250 (kubelet)

---

### 2.3 Node Security Group

**Created by**: Official EKS module automatically

**Name**: `eks-node-group-*`

**Inbound Rules**:
- **From Cluster SG**: Port 443, 10250 (kubelet API)
- **From Other Nodes**: All traffic (pod-to-pod communication)
- **From Load Balancers**: Ports exposed by services

**Outbound Rules**:
- All traffic allowed (for pulling images, reaching APIs, etc.)

---

## 3. Network Flow Diagrams

### 3.1 Bastion → EKS Cluster Flow

```
┌──────────────────────────────────────────────────────────────┐
│  Your Laptop                                                 │
│  └─ aws ssm start-session                                    │
│     ↓                                                         │
│  AWS Systems Manager (SSM)                                   │
│     ↓                                                         │
│  ┌────────────────────────────────────────┐                  │
│  │ Bastion Host (10.16.5.128)             │                  │
│  │ Security Group: bastion-sg             │                  │
│  │ IAM Role: bastion-role                 │                  │
│  │   - AmazonSSMManagedInstanceCore       │                  │
│  │   - AmazonEKSClusterPolicy             │                  │
│  │   - Custom EKS access policy           │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ kubectl get nodes                                      │
│     ↓ Port 443 (HTTPS)                                       │
│  ┌────────────────────────────────────────┐                  │
│  │ Security Group Rule Check              │                  │
│  │ ✓ Source: bastion-sg                   │                  │
│  │ ✓ Destination: cluster-sg              │                  │
│  │ ✓ Port: 443                            │                  │
│  │ ✓ Protocol: TCP                        │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ ALLOWED                                                │
│  ┌────────────────────────────────────────┐                  │
│  │ EKS Control Plane (10.16.151.26:443)   │                  │
│  │ Security Group: cluster-sg             │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ IAM Authentication                                     │
│  ┌────────────────────────────────────────┐                  │
│  │ EKS Access Entry Check                 │                  │
│  │ ✓ Principal: bastion-role ARN          │                  │
│  │ ✓ Policy: AmazonEKSClusterAdminPolicy  │                  │
│  │ ✓ Scope: cluster                       │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ AUTHORIZED                                             │
│  ┌────────────────────────────────────────┐                  │
│  │ Kubernetes API Response                │                  │
│  │ Returns: Node list, pod list, etc.     │                  │
│  └────────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

---

### 3.2 Pod → AWS Service Flow (IRSA)

```
┌──────────────────────────────────────────────────────────────┐
│  Pod (ebs-csi-controller)                                    │
│  Namespace: kube-system                                      │
│  Service Account: ebs-csi-controller-sa                      │
│     ↓                                                         │
│  ┌────────────────────────────────────────┐                  │
│  │ Service Account Token (JWT)            │                  │
│  │ Mounted at: /var/run/secrets/eks...    │                  │
│  │ Contains:                              │                  │
│  │   - Namespace: kube-system             │                  │
│  │   - SA Name: ebs-csi-controller-sa     │                  │
│  │   - Expiry: 1 hour                     │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ AWS SDK reads token                                    │
│  ┌────────────────────────────────────────┐                  │
│  │ AWS STS (Security Token Service)       │                  │
│  │ Validates token against OIDC provider  │                  │
│  │ OIDC URL: oidc.eks.us-east-1...        │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ Token valid?                                           │
│  ┌────────────────────────────────────────┐                  │
│  │ IAM Role Assumption                    │                  │
│  │ Role: dev-daas-eks-ebs-csi-driver      │                  │
│  │ Policy: AmazonEBSCSIDriverPolicy       │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ Returns temporary credentials                          │
│  ┌────────────────────────────────────────┐                  │
│  │ Temporary AWS Credentials              │                  │
│  │ Access Key: ASIA...                    │                  │
│  │ Secret Key: ...                        │                  │
│  │ Session Token: ...                     │                  │
│  │ Expiry: 1 hour                         │                  │
│  └────────────────────────────────────────┘                  │
│     ↓ Use credentials                                        │
│  ┌────────────────────────────────────────┐                  │
│  │ AWS EC2 API                            │                  │
│  │ Actions:                               │                  │
│  │   - CreateVolume                       │                  │
│  │   - AttachVolume                       │                  │
│  │   - DeleteVolume                       │                  │
│  └────────────────────────────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Access Control Summary

### 4.1 Who Can Access What?

| Principal | Access To | Method | Permissions |
|-----------|-----------|--------|-------------|
| **Your IAM User** | EKS Cluster | AWS Console / kubectl | Cluster Admin (via access entry) |
| **Bastion IAM Role** | EKS Cluster | kubectl from bastion | Cluster Admin (via access entry) |
| **Node IAM Role** | AWS APIs | Automatic | Worker node operations |
| **EBS CSI Pod** | EC2 API | IRSA | Create/attach volumes only |
| **Your Laptop** | Bastion | SSM | Shell access via IAM |

---

### 4.2 Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Network (Security Groups)                          │
│   ✓ Bastion can reach EKS API (port 443)                   │
│   ✓ Nodes can reach EKS API                                │
│   ✓ Pods can communicate with each other                   │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: IAM Authentication                                 │
│   ✓ Bastion has IAM role with EKS permissions              │
│   ✓ Your user has IAM permissions                          │
│   ✓ Pods have IRSA roles                                   │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: EKS Access Entries (Kubernetes RBAC)              │
│   ✓ Your IAM user → Cluster Admin                          │
│   ✓ Bastion IAM role → Cluster Admin                       │
│   ✓ Node IAM role → system:node (automatic)                │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Kubernetes RBAC (Optional - for fine-grained)     │
│   ✓ Can create additional roles/rolebindings               │
│   ✓ Can restrict namespace access                          │
│   ✓ Can limit resource types                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. How to Determine IAM Permissions Needed

### Decision Tree

```
Need to add a new component? Follow this:

┌─────────────────────────────────────────┐
│ What needs AWS permissions?             │
└─────────────────────────────────────────┘
         │
         ├─ EC2 Instance (Bastion, Node)
         │  └─> Create IAM Role
         │      └─> Attach policies
         │          └─> Attach to instance profile
         │
         ├─ Kubernetes Pod
         │  └─> Create IRSA Role
         │      └─> Link to Service Account
         │          └─> Pod uses SA
         │
         └─ Human User
            └─> Create/use IAM User
                └─> Add to EKS access entries
                    └─> Grant cluster permissions
```

### Example: Adding AWS Load Balancer Controller

**Question**: What IAM permissions does it need?

**Answer**:
1. **Type**: Kubernetes pod → Use IRSA
2. **AWS Actions Needed**:
   - Create/delete ALB/NLB
   - Modify target groups
   - Create security groups
   - Describe VPCs, subnets
3. **Implementation**:
```hcl
module "aws_load_balancer_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  role_name = "${var.cluster-name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true
  
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

---

## 6. Quick Reference

### IAM Role Checklist

When creating a new IAM role, ask:

1. **Who/what will use it?**
   - EC2 instance → Trust policy: `ec2.amazonaws.com`
   - Kubernetes pod → Trust policy: OIDC provider
   - Human → IAM user/role

2. **What AWS actions does it need?**
   - Read-only → Use AWS managed read policies
   - Write → Create custom policy with specific actions
   - Admin → Use admin policies (carefully!)

3. **What's the scope?**
   - Specific resources → Use `Resource: ["arn:..."]`
   - All resources → Use `Resource: "*"` (less secure)

4. **How long should credentials last?**
   - EC2 instance → Permanent (until instance stops)
   - IRSA pod → 1 hour (auto-renewed)
   - Human → Session duration (configurable)

### Security Group Checklist

When creating a security group rule, ask:

1. **Direction?**
   - Inbound (ingress) → Traffic coming IN
   - Outbound (egress) → Traffic going OUT

2. **Source/Destination?**
   - CIDR block → `10.16.0.0/16` or `0.0.0.0/0`
   - Security group → Reference another SG
   - Prefix list → AWS service endpoints

3. **Port?**
   - SSH → 22
   - HTTPS → 443
   - Kubernetes API → 443
   - Kubelet → 10250
   - All → 0-65535

4. **Protocol?**
   - TCP → Most common
   - UDP → DNS, some apps
   - ICMP → Ping
   - All → `-1`

---

## 7. Troubleshooting

### "Access Denied" Errors

```bash
# Check IAM role attached to bastion
aws sts get-caller-identity

# Check EKS access entries
aws eks list-access-entries --cluster-name dev-daas-eks

# Check if role has EKS permissions
aws iam get-role --role-name dev-daas-eks-bastion-role
aws iam list-attached-role-policies --role-name dev-daas-eks-bastion-role
```

### "Connection Timeout" Errors

```bash
# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check if bastion can reach EKS API
curl -k https://CAFF37CB8FBC59A96A086853B006BD8A.gr7.us-east-1.eks.amazonaws.com

# Check security group rules
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=sg-xxxxx"
```

---

## 8. Best Practices

### IAM
- ✅ Use IRSA for pods (not node IAM roles)
- ✅ Use least privilege principle
- ✅ Rotate credentials regularly (IRSA does this automatically)
- ✅ Use AWS managed policies when possible
- ✅ Audit IAM usage with CloudTrail

### Security Groups
- ✅ Be specific with source/destination
- ✅ Use security group references (not CIDR blocks) when possible
- ✅ Document each rule with descriptions
- ✅ Regularly audit unused rules
- ✅ Use separate SGs for different components

### Access Control
- ✅ Use SSM instead of SSH
- ✅ Enable MFA for IAM users
- ✅ Use access entries instead of aws-auth ConfigMap
- ✅ Limit cluster admin access
- ✅ Use Kubernetes RBAC for fine-grained control

---

**Questions?** Review the Terraform files:
- IAM: `module/bastion.tf`, `module/iam-irsa.tf`
- Security Groups: `module/bastion.tf`, EKS module handles cluster/node SGs
- Access: `module/eks-cluster.tf` (access_entries)
