resource "null_resource" "local_commands" {
  provisioner "local-exec" {
    command = <<-EOT
      
      echo "Current directory:"
      pwd
      echo "\nDirectory contents:"
      ls -la
      echo "\nZip version:"
      zip --version
      echo "\nNPM version:"
      npm --version
    EOT
  }
}

locals {
  lambda_name = "shorten-url-lambda"
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
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/us-${var.environment}-shortened-urls"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "custom_policy_attachment" {
  role       = module.lambda.lambda_role_name
  policy_arn = aws_iam_policy.custom_policy.arn
}
