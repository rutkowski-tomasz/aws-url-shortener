locals {
  ws_api_gateway_integration_count = var.ws_api_gateway_route != null ? 1 : 0
}

data "external" "ws_authorizer_id" {
  program = ["sh", "-c", "aws apigatewayv2 get-authorizers --api-id ${data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id} --query 'Items[?Name==`${local.prefix}websocket-cognito-authorizer`]|[0].{Id:AuthorizerId}'"]
}

data "aws_apigatewayv2_api" "websocket_api" {
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
}

resource "aws_apigatewayv2_route" "websocket_connect_route" {
  count              = local.ws_api_gateway_integration_count
  api_id             = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  route_key          = var.ws_api_gateway_route
  authorization_type = var.ws_api_gateway_requires_authorization ? "CUSTOM" : "NONE"
  authorizer_id      = var.ws_api_gateway_requires_authorization ? data.external.ws_authorizer_id.result.Id : null
  target             = "integrations/${aws_apigatewayv2_integration.websocket_default_integration[0].id}"
}

resource "aws_apigatewayv2_integration" "websocket_default_integration" {
  count            = local.ws_api_gateway_integration_count
  api_id           = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.lambda.arn
}

resource "aws_apigatewayv2_deployment" "deployment" {
  count  = local.ws_api_gateway_integration_count
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  depends_on = [ aws_apigatewayv2_route.websocket_connect_route ]

  triggers = {
    redeployment = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}
