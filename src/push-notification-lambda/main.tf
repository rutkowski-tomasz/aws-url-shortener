terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "us-cicd"
    key    = "terraform/push-notification-lambda"
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
  project            = "push-notification-lambda"
}

resource "null_resource" "validate_workspace" {
  count = local.is_valid_workspace ? 0 : 1
  provisioner "local-exec" {
    command = "echo Invalid workspace: '${terraform.workspace}'. Must be either 'dev' or 'prd'. && exit 1"
  }
}

###

module "lambda" {
  depends_on = [ aws_sns_topic.preview_generated ]
  source               = "../../terraform/modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  sns_topic_name       = aws_sns_topic.preview_generated.name

  custom_policy_statements = [
    {
      Action = "dynamodb:GetItem",
      Resource = "${data.aws_dynamodb_table.url_shortener.arn}"
    },
    {
      Action = "dynamodb:Query",
      Resource = "${data.aws_dynamodb_table.websocket_connections.arn}/index/UserIdIndex"
    },
    {
      Action: "execute-api:ManageConnections",
      Resource: "arn:aws:execute-api:*:*:${data.external.websocket_api_id.result.Id}/*/*/@connections/*"
    }
  ]

  environment_variables = {
    WS_API_GATEWAY_ID = data.external.websocket_api_id.result.Id
  }
}

data "aws_dynamodb_table" "url_shortener" {
  name = "${local.prefix}shortened-urls"
}

data "aws_dynamodb_table" "websocket_connections" {
  name = "${local.prefix}websocket-connections"
}

data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

data "external" "websocket_api_id" {
  program = ["sh", "-c", "aws apigatewayv2 get-apis --query 'Items[?Name==`${local.prefix}websocket-api`]|[0].{Id:ApiId}'"]
}

resource "aws_sns_topic" "preview_generated" {
  name = "${local.prefix}preview-generated"
  policy = <<POLICY
  {
    "Version":"2012-10-17",
    "Statement":
    [
      {
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:${local.prefix}preview-generated",
        "Condition":
        {
          "ArnLike": { "aws:SourceArn": "${data.aws_s3_bucket.url_shortener_preview_storage.arn}" }
        }
    }]
  }
  POLICY
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = data.aws_s3_bucket.url_shortener_preview_storage.id

  topic {
    topic_arn     = aws_sns_topic.preview_generated.arn
    events        = ["s3:ObjectCreated:*"]
  }
}