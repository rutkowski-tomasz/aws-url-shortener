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
  prefix      = "us-${local.environment}-"
  environment = terraform.workspace == "prd" ? terraform.workspace : "dev"
  project     = "websocket-authorizer-lambda"
}

###

module "lambda" {
  source               = "../../terraform/modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  pack_dependencies    = true
  additional_environment_variables = {
    USER_POOL_ID = data.aws_cognito_user_pools.user_pool.ids[0]
  }
}

data "aws_cognito_user_pools" "user_pool" {
  name = "${local.prefix}user-pool"
}
