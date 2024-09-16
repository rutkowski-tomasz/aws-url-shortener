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
  prefix      = "us-${local.environment}-"
  environment = terraform.workspace == "prd" ? terraform.workspace : "dev"
  project     = "websocket-manager-lambda"
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
      Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem"],
      Resource = data.aws_dynamodb_table.websocket_connections.arn
    }
  ]
}

data "aws_dynamodb_table" "websocket_connections" {
  name         = "${local.prefix}websocket-connections"
}
