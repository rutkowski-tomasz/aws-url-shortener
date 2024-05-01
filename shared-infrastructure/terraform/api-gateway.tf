resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "${local.prefix}url-shortener-api"
  description = "API Gateway for URL shortener"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.get_url_lambda_integration,
    aws_api_gateway_integration.shorten_url_lambda_integration,
    aws_api_gateway_authorizer.cognito_user_pool_authorizer
  ]
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${local.prefix}api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com",
        },
        Effect = "Allow",
        Sid = "",
      },
    ],
  })
}

resource "aws_iam_policy" "api_gateway_cloudwatch_policy" {
  name = "${local.prefix}api_gateway_cloudwatch_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ],
        Resource = "*",
        Effect = "Allow",
      },
    ],
  })
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.attach_cloudwatch_to_api_gateway,
  ]
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_to_api_gateway" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = aws_iam_policy.api_gateway_cloudwatch_policy.arn
}

resource "aws_api_gateway_stage" "stage" {
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  deployment_id = aws_api_gateway_deployment.deployment.id

  access_log_settings {
    format = jsonencode({
      requestId      = "$context.requestId",
      ip             = "$context.identity.sourceIp",
      caller         = "$context.identity.caller",
      user           = "$context.identity.user",
      requestTime    = "$context.requestTime",
      httpMethod     = "$context.httpMethod",
      resourcePath   = "$context.resourcePath",
      status         = "$context.status",
      protocol       = "$context.protocol",
      responseLength = "$context.responseLength"
    })
    destination_arn = "arn:aws:logs:eu-central-1:024853653660:log-group:/aws/apigateway/${local.prefix}url-shortener-api"
  }

  xray_tracing_enabled = true

  depends_on = [aws_api_gateway_deployment.deployment]
}
