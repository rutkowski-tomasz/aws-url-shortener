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
      name = "shared-infrastructure"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"

  default_tags {
    tags = {
      environment = "dev"
      application = "aws-url-shortener"
      project     = "shorten-url-lambda"
      terraform-managed = true
    }
  }
}
