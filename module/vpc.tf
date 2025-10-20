################################################################################
# VPC Module (Official)
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc-name
  cidr = var.cidr-block

  azs             = var.pri-availability-zone
  private_subnets = var.pri-cidr-block
  public_subnets  = var.pub-cidr-block

  enable_nat_gateway   = true
  single_nat_gateway   = false  # HA: One NAT per AZ for production
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
