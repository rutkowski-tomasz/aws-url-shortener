data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

module "lambda" {
  source                    = "../terraform-modules/lambda"
  environment               = var.environment
  lambda_function_name      = "get-preview-url-lambda"
  lambda_handler            = "index.handler"
  lambda_runtime            = "nodejs20.x"
  pack_dependencies         = true
  custom_policy_statements = [
    {
      Effect   = "Allow",
      Action   = "s3:GetObject",
      Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*",
    }
  ]
}
