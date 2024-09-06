locals {
  lambda_name = "get-preview-url-lambda"
}

data "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

module "lambda" {
  source               = "./modules/lambda"
  environment          = var.environment
  lambda_function_name = local.lambda_name
  lambda_handler       = "index.handler"
  lambda_runtime       = "nodejs20.x"
  deployment_package   = "deployment-package.zip"
}

resource "aws_iam_policy" "custom_policy" {
  name   = "${local.prefix}${local.lambda_name}-custom-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:GetObject",
        Resource = "${data.aws_s3_bucket.url_shortener_preview_storage.arn}/*",
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "custom_policy_attachment" {
  role       = module.lambda.lambda_role_name
  policy_arn = aws_iam_policy.custom_policy.arn
}
