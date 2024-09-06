locals {
  prefix = "us-${var.environment}-"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.prefix}${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.prefix}${var.lambda_function_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ],
          Resource = "arn:aws:logs:*:log-group:/aws/lambda/${local.prefix}${var.lambda_function_name}:*",
          Effect   = "Allow",
        }
      ],
      var.custom_policy_statements
    )
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "null_resource" "package_deployment" {
  triggers = {
    always_run: timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Packing src folder"
      cd src
      zip -qr ../deployment-package.zip .
      cd ..

      if [ "${var.pack_dependencies}" = "true" ]; then
        echo "Installing node_modules"
        npm i
        echo "Packing node_modules"
        zip -qr deployment-package.zip node_modules/
      fi

      aws s3 cp deployment-package.zip s3://us-cicd/${var.lambda_function_name}/deployment_package.zip

      rm deployment-package.zip
    EOT
    working_dir = path.root
  }
}

resource "aws_lambda_function" "lambda" {
  depends_on = [null_resource.package_deployment]
  function_name    = "${local.prefix}${var.lambda_function_name}"
  handler          = var.lambda_handler
  role             = aws_iam_role.lambda_execution_role.arn
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  layers           = var.lambda_layers
  s3_bucket        = "us-cicd"
  s3_key           = "${var.lambda_function_name}/deployment_package.zip"

  environment {
    variables = {
      environment = var.environment
    }
  }
}
