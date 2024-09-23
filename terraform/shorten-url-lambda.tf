
module "lambda" {
  source                             = "../../terraform/modules/lambda"
  environment                        = local.environment
  lambda_function_name               = local.project
  lambda_handler                     = "index.handler"
  lambda_runtime                     = "nodejs20.x"
  api_gateway_http_method            = "POST"
  api_gateway_resource_path          = "shorten-url"
  api_gateway_requires_authorization = true
  custom_policy_statements = [
    {
      Action   = "dynamodb:PutItem",
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls"
    }
  ]
}
