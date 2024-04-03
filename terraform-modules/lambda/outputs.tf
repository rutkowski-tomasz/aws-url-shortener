output "lambda_role_name" {
  description = "The name of the IAM role attached to the Lambda function."
  value       = aws_iam_role.lambda_execution_role.name
}
