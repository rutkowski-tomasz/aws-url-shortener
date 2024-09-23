
module "lambda" {
  source               = "../../terraform/modules/lambda"
  environment          = local.environment
  lambda_function_name = local.project
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"

  custom_policy_statements = [
    {
      Action = [
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      Resource = data.aws_dynamodb_table.websocket_connections.arn
    }
  ]
}

data "aws_dynamodb_table" "websocket_connections" {
  name = "${local.prefix}websocket-connections"
}


###

data "terraform_remote_state" "shared_infrastructure" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "us-cicd"
    key    = "terraform/shared-infrastructure"
    region = "eu-central-1"
  }
}

data "external" "ws_authorizer_id" {
  program = ["sh", "-c", "aws apigatewayv2 get-authorizers --api-id ${data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id} --query 'Items[?Name==`${local.prefix}websocket-cognito-authorizer`]|[0].{Id:AuthorizerId}'"]
}

data "aws_apigatewayv2_api" "websocket_api" {
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
}

resource "aws_apigatewayv2_route" "connect" {
  api_id             = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = data.external.ws_authorizer_id.result.Id
  target             = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id           = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  integration_type = "AWS_PROXY"
  integration_uri  = module.lambda.lambda_function_arn
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id = data.terraform_remote_state.shared_infrastructure.outputs.ws_api_gateway_api_id
  depends_on = [
    aws_apigatewayv2_route.connect,
    aws_apigatewayv2_route.disconnect
  ]

  triggers = {
    redeployment = timestamp()
  }
}

resource "aws_lambda_permission" "permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_apigatewayv2_api.websocket_api.execution_arn}/${local.environment}/*"
}
