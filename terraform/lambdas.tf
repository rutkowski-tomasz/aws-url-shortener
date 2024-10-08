module "dynamodb_stream_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "dynamodb-stream-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  depends_on = [aws_dynamodb_table.url_shortener]
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

module "generate_preview_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "generate-preview-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  lambda_memory_size   = 1024
  lambda_timeout       = 120

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
  api_gateway_model_schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "GET /get-preview-url"
    type      = "object"
    properties = {
      isSuccess = { type = "boolean" },
      error     = { type = "string" },
      result = {
        type = "object",
        properties = {
          desktopUrl = { type = "string" },
          mobileUrl  = { type = "string" }
        }
      }
    }
  })

  depends_on = [aws_api_gateway_rest_api.api_gateway]
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
      Resource : "arn:aws:execute-api:${data.aws_region.current.name}:*:${aws_apigatewayv2_api.websocket_api.id}/${local.environment}/*/@connections/*"
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
  api_gateway_model_schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "POST /shorten-url"
    type      = "object"
    properties = {
      isSuccess = { type = "boolean" }
      error     = { type = "string" }
      result = {
        type = "object"
        properties = {
          code      = { type = "string" },
          longUrl   = { type = "string" },
          userId    = { type = "string" },
          createdAt = { type = "number" }
        }
      }
    }
  })

  custom_policy_statements = [
    {
      Action   = "dynamodb:PutItem",
      Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/us-${local.environment}-shortened-urls"
    },
    {
      Action   = "scheduler:CreateSchedule",
      Resource = "arn:aws:scheduler:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schedule/default/us-${local.environment}-delete-shortened-url-*"
    },
    {
      Action = "iam:PassRole",
      Resource = aws_iam_role.scheduler_role.arn
    }
  ]

  environment_variables = {
    EVENT_BUS_ARN = aws_cloudwatch_event_bus.url_shortener.arn
    SCHEDULER_ROLE_ARN = aws_iam_role.scheduler_role.arn
  }
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

  depends_on = [aws_api_gateway_rest_api.api_gateway]
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

module "delete_url_lambda" {
  source               = "./modules/lambda"
  environment          = local.environment
  lambda_function_name = "delete-url-lambda"
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  sqs_queue_name       = aws_sqs_queue.shortener_url_delete_command.name

  depends_on = [
    aws_api_gateway_rest_api.api_gateway,
    aws_sqs_queue.shortener_url_delete_command
  ]

  custom_policy_statements = [
    {
      Action   = "dynamodb:UpdateItem",
      Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/us-${local.environment}-shortened-urls"
    },
    {
      Action   = "s3:DeleteObject",
      Resource = "${aws_s3_bucket.preview_storage.arn}/*"
    }
  ]
}
