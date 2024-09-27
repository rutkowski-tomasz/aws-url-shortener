resource "aws_api_gateway_resource" "get_my_links" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "get-my-links"
}

resource "aws_api_gateway_method" "get_my_links_get" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.get_my_links.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_user_pool_authorizer.id
}

resource "aws_api_gateway_integration" "get_my_links_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.get_my_links.id
  http_method             = aws_api_gateway_method.get_my_links_get.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/Query"
  credentials             = aws_iam_role.get_my_links_role.arn



  request_templates = {
    "application/json" = <<EOF
{
  "TableName": "${local.prefix}shortened-urls",
  "IndexName": "UserIdIndex",
  "KeyConditionExpression": "userId = :userId",
  "ExpressionAttributeValues": {
    ":userId": {
      "S": "$context.authorizer.claims.sub"
    }
  }
}
EOF
  }

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.0'"
  }
}

resource "aws_api_gateway_method_response" "get_my_links_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.get_my_links.id
  http_method = aws_api_gateway_method.get_my_links_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "get_my_links_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.get_my_links.id
  http_method = aws_api_gateway_method.get_my_links_get.http_method
  status_code = aws_api_gateway_method_response.get_my_links_response_200.status_code

  depends_on = [
    aws_api_gateway_integration.get_my_links_integration
  ]

  response_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "links": [
  #foreach($item in $inputRoot.Items)
    {
      "code": "$item.code.S",
      "longUrl": "$item.longUrl.S",
      "createdAt": "$item.createdAt.N"
    }#if($foreach.hasNext),#end
  #end
  ]
}
EOF
  }
}

resource "aws_iam_role" "get_my_links_role" {
  name = "${local.prefix}get-my-links-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "get_my_links_policy" {
  name = "${local.prefix}get-my-links-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action   = "dynamodb:Query",
        Resource = "${aws_dynamodb_table.url_shortener.arn}/index/UserIdIndex"
      },
      {
        Effect = "Allow",
        Action   = "dynamodb:Query",
        Resource = "${aws_dynamodb_table.url_shortener.arn}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_my_links_attachment" {
  role       = aws_iam_role.get_my_links_role.name
  policy_arn = aws_iam_policy.get_my_links_policy.arn
}