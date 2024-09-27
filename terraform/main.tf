terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/solution-infrastructure"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      environment       = local.environment
      application       = "aws-url-shortener"
      terraform-managed = true
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  is_valid_workspace = contains(["dev", "prd"], terraform.workspace)
  prefix             = "us-${local.environment}-"
  environment        = terraform.workspace
}

resource "null_resource" "validate_workspace" {
  count = local.is_valid_workspace ? 0 : 1
  provisioner "local-exec" {
    command = "echo Invalid workspace: '${terraform.workspace}'. Must be either 'dev' or 'prd'. && exit 1"
  }
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

output "ws_api_gateway_connect_url" {
  value = aws_apigatewayv2_stage.stage.invoke_url
}

output "ws_api_gateway_api_id" {
  value = aws_apigatewayv2_api.websocket_api.id
}
