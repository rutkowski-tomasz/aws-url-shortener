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
  source               = "../../terraform/modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  custom_policy_statements = [
    {
      Action = [
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      Resource = data.aws_dynamodb_table.websocket_connections.arn
    }
  ]
}

data "aws_dynamodb_table" "websocket_connections" {
  name = "${local.prefix}websocket-connections"
}


###

data "terraform_remote_state" "shared_infrastructure" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "us-cicd"
    key    = "terraform/shared-infrastructure"
    region = "eu-central-1"
  }
}

data "external" "ws_authorizer_id" {
  program = ["sh", "-c", "aws apigatewayv2 get-authorizers --api-id ${data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id} --query 'Items[?Name==`${local.prefix}websocket-cognito-authorizer`]|[0].{Id:AuthorizerId}'"]
}

data "aws_apigatewayv2_api" "websocket_api" {
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
}

resource "aws_apigatewayv2_route" "connect" {
  api_id             = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = data.external.ws_authorizer_id.result.Id
  target             = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id           = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  integration_type = "AWS_PROXY"
  integration_uri  = module.lambda.lambda_function_arn
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  depends_on = [
    aws_apigatewayv2_route.connect,
    aws_apigatewayv2_route.disconnect,
  ]

  triggers = {
    redeployment = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_lambda_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.websocket_api.execution_arn}/${local.environment}/*"
}
