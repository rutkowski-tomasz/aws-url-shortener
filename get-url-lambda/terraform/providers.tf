terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "trutkowski"

    workspaces {
      name = "get-url-lambda"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"

  default_tags {
    tags = {
      environment = var.environment
      application = "aws-url-shortener"
      project     = "get-url-lambda"
      terraform-managed = true
    }
  }
}

locals {
  prefix = "us-${var.environment}-"
}
