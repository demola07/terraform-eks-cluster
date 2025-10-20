################################################################################
# EKS Node Groups Configuration
################################################################################

locals {
  # Node group configurations
  node_groups = {
    # On-demand node group
    ondemand = {
      name = "${var.cluster-name}-od"  # Shortened: od = on-demand

      instance_types = var.ondemand_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.min_capacity_on_demand
      max_size     = var.max_capacity_on_demand
      desired_size = var.desired_capacity_on_demand

      # Encryption for node volumes
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        type = "ondemand"
      }

      tags = {
        Name = "${var.cluster-name}-od"
      }
    }
  }
}
