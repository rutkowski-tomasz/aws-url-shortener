
module "lambda" {
  source                          = "../../terraform/modules/lambda"
  environment                     = local.environment
  lambda_function_name            = local.project
  lambda_handler                  = "handler.handle"
  lambda_runtime                  = "python3.12"
  api_gateway_http_method         = "GET"
  api_gateway_resource_path       = "get-url"
  custom_policy_statements = [
    {
      Action   = "dynamodb:GetItem",
      Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${local.environment}-shortened-urls"
    }
  ]
}
