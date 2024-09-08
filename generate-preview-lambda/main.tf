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
  project     = ""
}

###

data "aws_sns_topic" "dynamodb_url_created_topic" {
  name = "${local.prefix}url-created"
}

data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

resource "aws_sqs_queue" "url_created_dlq" {
  name = "${local.prefix}url-created-generate-preview-dlq"
}

resource "aws_sqs_queue" "url_created_generate_preview" {
  name = "${local.prefix}url-created-generate-preview"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.url_created_dlq.arn,
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "url_created_generate_preview_policy" {
  queue_url = aws_sqs_queue.url_created_generate_preview.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.url_created_generate_preview.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = data.aws_sns_topic.dynamodb_url_created_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "url_created_subscription" {
  topic_arn = data.aws_sns_topic.dynamodb_url_created_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.url_created_generate_preview.arn
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.url_created_generate_preview.arn
  function_name    = module.lambda.lambda_function_name
  enabled          = true
  batch_size       = 10
}

module "lambda" {
  source               = "../terraform-modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  lambda_memory_size   = 1024
  lambda_timeout       = 30
  # Layer: https://github.com/shelfio/chrome-aws-lambda-layer
  lambda_layers = ["arn:aws:lambda:eu-central-1:764866452798:layer:chrome-aws-lambda:47"]
  custom_policy_statements = [
    {
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      Resource = aws_sqs_queue.url_created_generate_preview.arn
    },
    {
      Action   = ["s3:PutObject"],
      Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*"
    }
  ]
}