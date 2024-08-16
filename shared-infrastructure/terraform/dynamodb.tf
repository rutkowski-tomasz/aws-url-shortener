resource "aws_dynamodb_table" "url_shortener" {
  name         = "${local.prefix}shortened-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

resource "aws_sns_topic" "dynamodb_stream_topic" {
  name = "${local.prefix}url-created"
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn  = aws_dynamodb_table.url_shortener.stream_arn
  function_name     = data.terraform_remote_state.dynamodb_stream_lambda_state.outputs.lambda_function_arn
  starting_position = "LATEST"
}
