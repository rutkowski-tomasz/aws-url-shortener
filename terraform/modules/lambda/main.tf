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

resource "aws_lambda_function" "lambda" {
  function_name = "${local.prefix}${var.lambda_function_name}"
  handler       = var.lambda_handler
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  layers        = var.lambda_layers
  filename      = "../dist/${var.lambda_function_name}.zip"
  source_code_hash = filebase64sha256("../dist/${var.lambda_function_name}.zip")

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
      },
      var.environment_variables
    )
  }
}
