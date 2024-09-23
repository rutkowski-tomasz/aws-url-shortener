
data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

module "lambda" {
  source                    = "../../terraform/modules/lambda"
  environment               = local.environment
  lambda_function_name      = local.project
  lambda_handler            = "index.handler"
  lambda_runtime            = "nodejs20.x"
  api_gateway_http_method   = "GET"
  api_gateway_resource_path = "get-preview-url"
  custom_policy_statements = [
    {
      Action   = "s3:GetObject",
      Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*",
    }
  ]
}
