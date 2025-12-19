terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.23.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
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
