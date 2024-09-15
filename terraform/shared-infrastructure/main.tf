terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/shared-infrastructure"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      environment       = local.environment
      application       = "aws-url-shortener"
      project           = local.project
      terraform-managed = true
    }
  }
}

data "aws_region" "current" { }

locals {
  prefix      = "us-${local.environment}-"
  environment = terraform.workspace == "prd" ? terraform.workspace : "dev"
  project     = "shared-infrastructure"
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "cognito_url" {
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/"
}

output "api_gateway_health_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}${local.environment}/health"
}