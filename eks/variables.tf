################################################################################
# Variables for OFFICIAL EKS module
# Simplified - only essential variables needed
################################################################################

variable "aws-region" {
  description = "AWS region"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster-name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc-cidr-block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "vpc-name" {
  description = "Name of the VPC"
  type        = string
}

variable "pub-cidr-block" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "pub-availability-zone" {
  description = "Availability zones for public subnets"
  type        = list(string)
}

variable "pri-cidr-block" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "pri-availability-zone" {
  description = "Availability zones for private subnets"
  type        = list(string)
}

# EKS Configuration
variable "cluster-version" {
  description = "Kubernetes version"
  type        = string
}

variable "endpoint-private-access" {
  description = "Enable private API endpoint"
  type        = bool
}

variable "endpoint-public-access" {
  description = "Enable public API endpoint"
  type        = bool
}

variable "ondemand_instance_types" {
  description = "Instance types for on-demand node group"
  type        = list(string)
  default     = ["t3a.medium"]
}

variable "desired_capacity_on_demand" {
  description = "Desired capacity for on-demand nodes"
  type        = number
}

variable "min_capacity_on_demand" {
  description = "Minimum capacity for on-demand nodes"
  type        = number
}

variable "max_capacity_on_demand" {
  description = "Maximum capacity for on-demand nodes"
  type        = number
}

# Bastion Variables
variable "enable_bastion" {
  description = "Enable bastion/jump box"
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_enable_ssh" {
  description = "Enable SSH access to bastion (if false, only SSM access - more secure)"
  type        = bool
  default     = false # Default to SSM-only
}

variable "bastion_key_name" {
  description = "SSH key name for bastion host (only required if bastion_enable_ssh is true)"
  type        = string
  default     = ""
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion (only used if bastion_enable_ssh is true)"
  type        = list(string)
  default     = []
}