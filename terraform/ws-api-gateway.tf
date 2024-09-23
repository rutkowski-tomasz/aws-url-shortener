resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "${local.prefix}websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_iam_role" "websocket_api_gateway_cloudwatch_role" {
  name = "${local.prefix}websocket_api_gateway_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = "",
      }
    ],
  })
}

resource "aws_iam_policy" "websocket_api_gateway_cloudwatch_policy" {
  name = "${local.prefix}websocket_api_gateway_cloudwatch_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Resource = "*",
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_websocket_cloudwatch_policy" {
  role       = aws_iam_role.websocket_api_gateway_cloudwatch_role.name
  policy_arn = aws_iam_policy.websocket_api_gateway_cloudwatch_policy.arn
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = local.environment
  auto_deploy = true
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id = aws_apigatewayv2_api.websocket_api.id
  depends_on = [
    aws_apigatewayv2_route.websocket_manager_lambda_connect,
    aws_apigatewayv2_route.websocket_manager_lambda_disconnect
  ]

  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_apigatewayv2_authorizer" "websocket_lambda_authorizer" {
  name             = "${local.prefix}websocket-cognito-authorizer"
  api_id           = aws_apigatewayv2_api.websocket_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = module.websocket_authorizer_lambda.lambda_function_invoke_arn
  identity_sources = ["route.request.header.Authorization"]
}

resource "aws_lambda_permission" "websocket_authorizer_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.websocket_authorizer_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_route" "websocket_manager_lambda_connect" {
  api_id             = aws_apigatewayv2_api.websocket_api.id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.websocket_lambda_authorizer.id
  target             = "integrations/${aws_apigatewayv2_integration.websocket_manager_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "websocket_manager_lambda_disconnect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_manager_lambda_integration.id}"
}

resource "aws_apigatewayv2_integration" "websocket_manager_lambda_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = module.websocket_manager_lambda.lambda_function_arn
}

resource "aws_lambda_permission" "websocket_manager_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.websocket_manager_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/${local.environment}/*"
}
