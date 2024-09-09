terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/generate-preview-lambda"
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
  project     = "generate-preview-lambda"
}

###

data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

module "lambda" {
  source               = "../terraform-modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  lambda_memory_size   = 1024
  lambda_timeout       = 30
  pack_dependencies    = true 
  # Layer: https://github.com/shelfio/chrome-aws-lambda-layer
  lambda_layers = ["arn:aws:lambda:eu-central-1:764866452798:layer:chrome-aws-lambda:47"]
  custom_policy_statements = [
    {
      Action   = "s3:PutObject",
      Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*"
    }
  ]
  sns_topic_name = "${local.prefix}url-created"
}
