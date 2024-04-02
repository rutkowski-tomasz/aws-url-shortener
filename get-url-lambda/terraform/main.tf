resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.prefix}get-url-lambda-role"

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
    
resource "aws_iam_policy" "lambda_logging" {
  name = "${local.prefix}get-url-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect = "Allow",
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_dynamodb_access" {
  name   = "${local.prefix}get-url-lambda-dynamodb-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = "arn:aws:dynamodb:eu-central-1:024853653660:table/ShortenedUrls"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_access.arn
}

resource "aws_lambda_function" "get_url" {
  function_name = "${local.prefix}get-url-lambda"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.12"
  filename      = "deployment-package.zip"
}
