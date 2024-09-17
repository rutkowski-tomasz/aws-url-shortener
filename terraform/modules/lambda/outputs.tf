output "lambda_role_name" {
  description = "The name of the IAM role attached to the Lambda function."
  value       = aws_iam_role.lambda_execution_role.name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function."
  value       = aws_lambda_function.lambda.arn
}

output "lambda_function_invoke_arn" {
  description = "The Invoke ARN of the Lambda function."
  value       = aws_lambda_function.lambda.invoke_arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.lambda.function_name
}

output "api_gateway_url" {
  description = "The URL of the API Gateway endpoint for this Lambda function."
  value       = var.api_gateway_resource_path != null ? "${aws_api_gateway_deployment.deployment.invoke_url}${var.environment}/${var.api_gateway_resource_path}" : null
}