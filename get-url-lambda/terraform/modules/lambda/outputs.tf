output "lambda_role_name" {
  description = "The name of the IAM role attached to the Lambda function."
  value       = aws_iam_role.lambda_execution_role.name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function."
  value       = aws_lambda_function.lambda.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.lambda.function_name
}
