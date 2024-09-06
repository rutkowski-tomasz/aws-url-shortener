terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/get-preview-url-lambda"
    region = "eu-central-1"
  }
}
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      environment       = local.environment
      application       = "aws-url-shortener"
      project           = "get-preview-url-lambda"
      terraform-managed = true
    }
  }
}

locals {
  prefix      = "us-${local.environment}-"
  environment = terraform.workspace == "default" ? "dev" : terraform.workspace
}

###

data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

module "lambda" {
  source               = "../terraform-modules/lambda"
  environment          = local.environment
  lambda_function_name = "get-preview-url-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  pack_dependencies    = true
  custom_policy_statements = [
    {
      Effect   = "Allow",
      Action   = "s3:GetObject",
      Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*",
    }
  ]
}
