################################################################################
# Bastion Outputs
################################################################################

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = var.enable_bastion ? aws_eip.bastion[0].public_ip : null
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion (only if SSH is enabled)"
  value       = var.enable_bastion && var.bastion_enable_ssh ? "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion[0].public_ip}" : "SSH access disabled - use SSM instead"
}

output "bastion_ssm_command" {
  description = "AWS SSM command to connect to bastion (recommended - no SSH key needed)"
  value       = var.enable_bastion ? "aws ssm start-session --target ${aws_instance.bastion[0].id} --region ${data.aws_region.current.name}" : null
}

output "bastion_access_method" {
  description = "How to access the bastion"
  value = var.enable_bastion ? (
    var.bastion_enable_ssh ? "SSH and SSM both enabled" : "SSM only (more secure)"
  ) : "Bastion disabled"
}
