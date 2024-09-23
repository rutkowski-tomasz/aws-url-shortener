
module "lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  custom_policy_statements = [
    {
      Action   = ["sns:Publish"],
      Resource = "arn:aws:sns:eu-central-1:024853653660:us-${local.environment}-url-created"
    },
    {
      Action = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ],
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls/stream/*"
    }
  ]
}

data "aws_dynamodb_table" "url_shortener" {
  name         = "${local.prefix}shortened-urls"
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn  = data.aws_dynamodb_table.url_shortener.stream_arn
  function_name     = module.lambda.lambda_function_arn
  starting_position = "LATEST"
}

resource "aws_sns_topic" "dynamodb_stream_topic" {
  name = "${local.prefix}url-created"
}