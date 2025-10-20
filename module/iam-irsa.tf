################################################################################
# IAM Roles for Service Accounts (IRSA)
################################################################################

# EBS CSI Driver IRSA
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster-name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Add more IRSA roles here as needed
# Example: AWS Load Balancer Controller, External DNS, Cluster Autoscaler, etc.
