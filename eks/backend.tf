terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0, < 6.0.0"
    }
  }
  # Temporarily using local backend for experimentation
  # Uncomment this when ready for production with S3 backend
  # backend "s3" {
  #   bucket         = "dev-aman-tf-bucket"
  #   region         = "us-east-1"
  #   key            = "eks/terraform.tfstate"
  #   dynamodb_table = "Lock-Files"
  # use_lockfile = true
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws-region
}