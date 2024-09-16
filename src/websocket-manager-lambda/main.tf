terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/websocket-manager-lambda"
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

locals {
  is_valid_workspace = contains(["dev", "prd"], terraform.workspace)
  prefix             = "us-${local.environment}-"
  environment        = terraform.workspace
  project            = "websocket-manager-lambda"
}

resource "null_resource" "validate_workspace" {
  count = local.is_valid_workspace ? 0 : 1
  provisioner "local-exec" {
    command = "echo Invalid workspace: '${terraform.workspace}'. Must be either 'dev' or 'prd'. && exit 1"
  }
}

###

module "lambda" {
  source                                = "../../terraform/modules/lambda"
  environment                           = local.environment
  lambda_function_name                  = local.project
  lambda_handler                        = "index.handler"
  lambda_runtime                        = "nodejs20.x"
  ws_api_gateway_route                  = "$connect"
  ws_api_gateway_requires_authorization = true

  custom_policy_statements = [
    {
      Action   = [
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem"
      ],
      Resource = data.aws_dynamodb_table.websocket_connections.arn
    }
  ]
}

data "aws_dynamodb_table" "websocket_connections" {
  name = "${local.prefix}websocket-connections"
}
