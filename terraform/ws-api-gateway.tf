resource "aws_apigatewayv2_api" "websocket_api" {
  name          = "${local.prefix}websocket-api"
  protocol_type = "WEBSOCKET"
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
