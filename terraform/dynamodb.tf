resource "aws_dynamodb_table" "url_shortener" {
  name         = "${local.prefix}shortened-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

resource "aws_dynamodb_table" "websocket_connections" {
  name         = "${local.prefix}websocket-connections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "connectionId"

  attribute {
    name = "connectionId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    projection_type = "ALL"
  }
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn  = aws_dynamodb_table.url_shortener.stream_arn
  function_name     = module.dynamodb_stream_lambda.lambda_function_arn
  starting_position = "LATEST"
}

resource "aws_sns_topic" "dynamodb_stream_topic" {
  name           = "${local.prefix}url-created"
  tracing_config = "Active"
}
