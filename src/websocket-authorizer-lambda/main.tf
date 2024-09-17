terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/websocket-authorizer-lambda"
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
  project            = "websocket-authorizer-lambda"
}

resource "null_resource" "validate_workspace" {
  count = local.is_valid_workspace ? 0 : 1
  provisioner "local-exec" {
    command = "echo Invalid workspace: '${terraform.workspace}'. Must be either 'dev' or 'prd'. && exit 1"
  }
}

###

module "lambda" {
  source               = "../../terraform/modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  pack_dependencies    = true

  environment_variables = {
    USER_POOL_ID = data.aws_cognito_user_pools.user_pool.ids[0]
  }
}

data "aws_cognito_user_pools" "user_pool" {
  name = "${local.prefix}user-pool"
}

data "external" "websocket_api_id" {
  program = ["sh", "-c", "aws apigatewayv2 get-apis --query 'Items[?Name==`${local.prefix}websocket-api`]|[0].{Id:ApiId}'"]
}

data "aws_apigatewayv2_api" "websocket_api" {
  api_id = data.external.websocket_api_id.result.Id
}

resource "aws_apigatewayv2_authorizer" "websocket_lambda_authorizer" {
  name             = "${local.prefix}websocket-cognito-authorizer"
  api_id           = data.aws_apigatewayv2_api.websocket_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = module.lambda.lambda_function_invoke_arn
  identity_sources = ["route.request.header.Authorization"]
}

resource "aws_lambda_permission" "permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.websocket_api.execution_arn}/*/*"
}
