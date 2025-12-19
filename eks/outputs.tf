################################################################################
# Outputs - Works with both custom and official modules
################################################################################

# Uncomment the appropriate outputs based on which module you're using

################################################################################
# For OFFICIAL module (when using main-official.tf)
################################################################################

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = try(module.eks.cluster_endpoint, null)
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = try(module.eks.cluster_name, null)
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = try(module.eks.cluster_certificate_authority_data, null)
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = try(module.eks.oidc_provider_arn, null)
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = try(module.eks.configure_kubectl, "Run: aws eks update-kubeconfig --region ${var.aws-region} --name <cluster-name>")
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(module.eks.vpc_id, null)
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = try(module.eks.private_subnets, null)
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = try(module.eks.public_subnets, null)
}

################################################################################
# Bastion Outputs
################################################################################

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = try(module.eks.bastion_public_ip, null)
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = try(module.eks.bastion_instance_id, null)
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion (only if SSH is enabled)"
  value       = try(module.eks.bastion_ssh_command, null)
}

output "bastion_ssm_command" {
  description = "AWS SSM command to connect to bastion (recommended - no SSH key needed)"
  value       = try(module.eks.bastion_ssm_command, null)
}

output "bastion_access_method" {
  description = "How to access the bastion"
  value       = try(module.eks.bastion_access_method, null)
}

################################################################################
# IRSA Outputs
################################################################################

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = try(module.eks.aws_load_balancer_controller_role_arn, null)
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI Driver"
  value       = try(module.eks.ebs_csi_driver_role_arn, null)
}
