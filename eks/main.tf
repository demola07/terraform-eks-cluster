################################################################################
# Main configuration using OFFICIAL EKS module
# To use this instead of the custom module:
# 1. Rename main.tf to main-custom.tf
# 2. Rename this file to main.tf
# 3. Run: terraform init -upgrade
################################################################################

locals {
  org = "daas"
  env = var.env
}

module "eks" {
  source = "../module"

  env                        = var.env
  cluster-name               = "${local.env}-${local.org}-${var.cluster-name}"
  cidr-block                 = var.vpc-cidr-block
  vpc-name                   = "${local.env}-${local.org}-${var.vpc-name}"
  pub-cidr-block             = var.pub-cidr-block
  pub-availability-zone      = var.pub-availability-zone
  pri-cidr-block             = var.pri-cidr-block
  pri-availability-zone      = var.pri-availability-zone
  ondemand_instance_types    = var.ondemand_instance_types
  desired_capacity_on_demand = var.desired_capacity_on_demand
  min_capacity_on_demand     = var.min_capacity_on_demand
  max_capacity_on_demand     = var.max_capacity_on_demand
  cluster-version            = var.cluster-version
  endpoint-private-access    = var.endpoint-private-access
  endpoint-public-access     = var.endpoint-public-access

  # Bastion configuration
  enable_bastion        = var.enable_bastion
  bastion_instance_type = var.bastion_instance_type
  bastion_enable_ssh    = var.bastion_enable_ssh
  bastion_key_name      = var.bastion_key_name
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
}