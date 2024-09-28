resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "${local.prefix}url-shortener-api"
  description = "API Gateway for URL shortener"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
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
        Sid    = "",
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
        Effect   = "Allow",
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
  stage_name    = local.environment
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  xray_tracing_enabled = true
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "health"
}
resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "health_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}
resource "aws_api_gateway_method_response" "health_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = "200"
}
resource "aws_api_gateway_integration_response" "health_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = aws_api_gateway_method_response.health_response_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      status = "healthy"
    })
  }
}
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id

  triggers = {
    redeployment = timestamp()
  }

  depends_on = [
    aws_api_gateway_integration.get_my_urls_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_api_gateway_export" "swagger_export" {
  rest_api_id = aws_api_gateway_stage.stage.rest_api_id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  export_type = "swagger"
}

resource "aws_s3_object" "swagger_upload" {
  bucket = "us-cicd"
  key    = "docs/swagger.json"
  content = data.aws_api_gateway_export.swagger_export.body
}
