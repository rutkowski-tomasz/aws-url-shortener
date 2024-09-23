resource "aws_cognito_user_pool" "user_pool" {
  name                     = "${local.prefix}user-pool"
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "client" {
  name                = "${local.prefix}user-pool-client"
  user_pool_id        = aws_cognito_user_pool.user_pool.id
  generate_secret     = false
  explicit_auth_flows = ["ADMIN_NO_SRP_AUTH", "USER_PASSWORD_AUTH"]
}

resource "aws_api_gateway_authorizer" "cognito_user_pool_authorizer" {
  name            = "${local.prefix}user-pool-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.api_gateway.id
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.user_pool.arn]
  type            = "COGNITO_USER_POOLS"
}
