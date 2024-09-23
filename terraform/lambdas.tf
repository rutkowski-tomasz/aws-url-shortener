module "dynamodb_stream_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "dynamodb-stream-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  depends_on = [ aws_dynamodb_table.url_shortener ]
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

module "generate_stream_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "generate-stream-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  lambda_memory_size   = 1024
  lambda_timeout       = 30

  # Layer: https://github.com/shelfio/chrome-aws-lambda-layer
  lambda_layers = ["arn:aws:lambda:eu-central-1:764866452798:layer:chrome-aws-lambda:47"]

  depends_on = [aws_sns_topic.dynamodb_stream_topic]
  custom_policy_statements = [
    {
      Action   = "s3:PutObject",
      Resource = "${aws_s3_bucket.preview_storage.arn}/*"
    }
  ]
  sns_topic_name = aws_sns_topic.dynamodb_stream_topic.name
}

module "get_preview_url_lambda" {
  source                    = "./modules/lambda"
  environment               = local.environment
  lambda_function_name      = "get-preview-url-lambda"
  lambda_handler            = "index.handler"
  lambda_runtime            = "nodejs20.x"
  api_gateway_http_method   = "GET"
  api_gateway_resource_path = "get-preview-url"

  depends_on                = [aws_api_gateway_rest_api.api_gateway]
  custom_policy_statements = [
    {
      Action   = "s3:GetObject",
      Resource = "${aws_s3_bucket.preview_storage.arn}/*",
    }
  ]
}

module "get_url_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "get-url-lambda"
  lambda_handler       = "handler.handle"
  lambda_runtime       = "python3.12"

  depends_on                = [aws_api_gateway_rest_api.api_gateway]
  api_gateway_http_method   = "GET"
  api_gateway_resource_path = "get-url"

  custom_policy_statements = [
    {
      Action   = "dynamodb:GetItem",
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls"
    }
  ]
}

module "push_notification_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "push-notification-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  depends_on     = [aws_sns_topic.preview_generated]
  sns_topic_name = aws_sns_topic.preview_generated.name

  custom_policy_statements = [
    {
      Action   = "dynamodb:GetItem",
      Resource = "${aws_dynamodb_table.url_shortener.arn}"
    },
    {
      Action   = "dynamodb:Query",
      Resource = "${aws_dynamodb_table.websocket_connections.arn}/index/UserIdIndex"
    },
    {
      Action : "execute-api:ManageConnections",
      Resource : "arn:aws:execute-api:*:*:${aws_s3_bucket.preview_storage.id}/*/*/@connections/*"
    }
  ]

  environment_variables = {
    WS_API_GATEWAY_ID = aws_apigatewayv2_api.websocket_api.id
  }
}

module "shorten_url_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "shorten-url-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  depends_on                         = [aws_api_gateway_rest_api.api_gateway]
  api_gateway_http_method            = "POST"
  api_gateway_resource_path          = "shorten-url"
  api_gateway_requires_authorization = true

  custom_policy_statements = [
    {
      Action   = "dynamodb:PutItem",
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls"
    }
  ]
}

module "websocket_authorizer_lambda" {
  depends_on           = [aws_api_gateway_rest_api.api_gateway]
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "websocket-authorizer-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  environment_variables = {
    USER_POOL_ID = aws_cognito_user_pool.user_pool.id
  }
}

module "websocket_manager_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "websocket-manager-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  depends_on                = [aws_api_gateway_rest_api.api_gateway]
  custom_policy_statements = [
    {
      Action = [
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      Resource = aws_dynamodb_table.websocket_connections.arn
    }
  ]
}
