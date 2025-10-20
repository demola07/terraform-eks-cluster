################################################################################
# EKS Cluster (Official Module)
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster-name
  cluster_version = var.cluster-version

  # Networking
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster access
  cluster_endpoint_private_access = var.endpoint-private-access
  cluster_endpoint_public_access  = var.endpoint-public-access

  # Security: Allow public access from anywhere (bastion uses private endpoint)
  # Since bastion is in the VPC, it will use the private endpoint
  cluster_endpoint_public_access_cidrs = var.endpoint-public-access ? ["0.0.0.0/0"] : []
  
  # Additional security groups for cluster access
  cluster_additional_security_group_ids = var.enable_bastion ? [aws_security_group.bastion.id] : []

  # Enable cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Modern authentication mode
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true
  
  # Access entries for bastion
  access_entries = var.enable_bastion ? {
    bastion = {
      principal_arn = aws_iam_role.bastion.arn
      
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  } : {}

  # Cluster addons - using most_recent for automatic version management
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Node groups defined in separate file (eks-node-groups.tf)
  eks_managed_node_groups = local.node_groups

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
