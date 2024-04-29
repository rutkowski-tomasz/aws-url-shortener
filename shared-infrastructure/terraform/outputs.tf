output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}${var.environment}"
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "cognito_url" {
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/"
}
