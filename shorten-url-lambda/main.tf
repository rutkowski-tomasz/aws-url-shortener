terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/shorten-url-lambda"
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
  environment = terraform.workspace == "default" ? "dev" : terraform.workspace
  project     = "shorten-url-lambda"
}

module "lambda" {
  source               = "../terraform-modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  custom_policy_statements = [
    {
      Action   = "dynamodb:PutItem",
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls"
    }
  ]
}
