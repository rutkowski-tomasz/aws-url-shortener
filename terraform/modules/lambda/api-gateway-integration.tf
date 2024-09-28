locals {
  api_gateway_integration_count = var.api_gateway_http_method != null && var.api_gateway_resource_path != null ? 1 : 0
}

data "aws_api_gateway_rest_api" "api_gateway" {
  name = "${local.prefix}url-shortener-api"
}

data "external" "authorizer_id" {
  program = ["sh", "-c", "aws apigateway get-authorizers --rest-api-id ${data.aws_api_gateway_rest_api.api_gateway.id} --query 'items[0].{Id:id}'"]
}

data "aws_api_gateway_authorizer" "cognito_user_pool_authorizer" {
  authorizer_id = data.external.authorizer_id.result.Id
  rest_api_id   = data.aws_api_gateway_rest_api.api_gateway.id
}

resource "aws_api_gateway_resource" "lambda_resource" {
  count       = local.api_gateway_integration_count
  rest_api_id = data.aws_api_gateway_rest_api.api_gateway.id
  parent_id   = data.aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = var.api_gateway_resource_path
}

resource "aws_api_gateway_method" "lambda_method" {
  count         = local.api_gateway_integration_count
  rest_api_id   = data.aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.lambda_resource[0].id
  http_method   = var.api_gateway_http_method
  authorization = var.api_gateway_requires_authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id = var.api_gateway_requires_authorization ? data.aws_api_gateway_authorizer.cognito_user_pool_authorizer.id : null
}

resource "aws_api_gateway_integration" "lambda_integration" {
  count                   = local.api_gateway_integration_count
  rest_api_id             = data.aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.lambda_resource[0].id
  http_method             = aws_api_gateway_method.lambda_method[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "success_response" {
  count         = var.api_gateway_model_schema != null ? 1 : 0
  rest_api_id   = data.aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.lambda_resource[0].id
  http_method   = aws_api_gateway_method.lambda_method[0].http_method
  status_code   = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.response_model[0].name
  }
}

resource "aws_api_gateway_model" "response_model" {
  count         = var.api_gateway_model_schema != null ? 1 : 0
  rest_api_id   = data.aws_api_gateway_rest_api.api_gateway.id
  name         = replace(title("${lower(var.api_gateway_http_method)}-${var.api_gateway_resource_path}-response-model"), "-", "")
  description  = "API response for ${var.api_gateway_http_method} /${var.api_gateway_resource_path}"
  content_type = "application/json"
  schema = var.api_gateway_model_schema
}

resource "aws_lambda_permission" "api_gateway_permission" {
  count         = local.api_gateway_integration_count
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_api_gateway_rest_api.api_gateway.execution_arn}/*/${var.api_gateway_http_method}/${var.api_gateway_resource_path}"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = data.aws_api_gateway_rest_api.api_gateway.id
  stage_name  = var.environment
  description = "Deployed on ${timestamp()}"

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.lambda_method,
    aws_api_gateway_resource.lambda_resource,
    # aws_api_gateway_method_response.success_response,
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.lambda_resource,
      aws_api_gateway_method.lambda_method,
      aws_api_gateway_integration.lambda_integration,
      # aws_api_gateway_method_response.success_response,
    ]))
  }
}
