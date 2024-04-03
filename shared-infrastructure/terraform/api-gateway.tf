resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "${local.prefix}url-shortener-api"
  description = "API Gateway for URL shortener"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_url_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.get_url_lambda_state.outputs.lambda_function_arn
}

resource "aws_api_gateway_integration" "shorten_url_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.shorten_url_lambda_state.outputs.lambda_function_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.get_url_lambda_integration, aws_api_gateway_integration.shorten_url_lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = var.environment
}

output "api_gateway_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}