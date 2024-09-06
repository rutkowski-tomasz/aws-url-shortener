terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/get-preview-url-lambda"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      environment       = local.environment
      application       = "aws-url-shortener"
      project           = "get-preview-url-lambda"
      terraform-managed = true
    }
  }
}

locals {
  prefix = "us-${local.environment}-"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prd)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "The environment variable must be one of: dev, prd."
  }
}

data "terraform_remote_state" "current" {
  backend = "s3"
  config = {
    bucket = "us-cicd"
    key    = "terraform/get-preview-url-lambda"
    region = "eu-central-1"
  }
}

locals {
  workspace_name = terraform.workspace
  environment    = local.workspace_name == "default" ? "dev" : local.workspace_name
}
