
resource "aws_api_gateway_resource" "get_url" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "get-url"
}

resource "aws_api_gateway_method" "get_url_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.get_url.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_url_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.get_url.id
  http_method             = aws_api_gateway_method.get_url_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/${data.terraform_remote_state.get_url_lambda_state.outputs.lambda_function_arn}/invocations"
}
resource "aws_lambda_permission" "api_gateway_permission_get_url" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.get_url_lambda_state.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/GET/get-url"
}

resource "aws_api_gateway_resource" "shorten_url" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "shorten-url"
}

resource "aws_api_gateway_method" "shorten_url_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.shorten_url.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_user_pool_authorizer.id
}

resource "aws_api_gateway_integration" "shorten_url_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.shorten_url.id
  http_method             = aws_api_gateway_method.shorten_url_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:eu-central-1:lambda:path/2015-03-31/functions/${data.terraform_remote_state.shorten_url_lambda_state.outputs.lambda_function_arn}/invocations"
}

resource "aws_lambda_permission" "api_gateway_permission_shorten_url" {
  statement_id  = "AllowExecutionFromAPIGatewayShortenUrl"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.shorten_url_lambda_state.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/POST/shorten-url"
}