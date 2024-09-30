resource "aws_api_gateway_resource" "get_my_urls" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "get-my-urls"
}

resource "aws_api_gateway_method" "get_my_urls_get" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.get_my_urls.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_user_pool_authorizer.id
}

resource "aws_api_gateway_integration" "get_my_urls_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.get_my_urls.id
  http_method             = aws_api_gateway_method.get_my_urls_get.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/Query"
  credentials             = aws_iam_role.get_my_urls_role.arn

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

resource "aws_api_gateway_method_response" "get_my_urls_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.get_my_urls.id
  http_method = aws_api_gateway_method.get_my_urls_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.get_my_urls_response_model.name
  }
}

resource "aws_api_gateway_model" "get_my_urls_response_model" {
  rest_api_id  = aws_api_gateway_rest_api.api_gateway.id
  name         = "GetMyUrlsResponseModel"
  description  = "API response for GET /get-my-urls"
  content_type = "application/json"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "GET /get-my-urls"
    type      = "object"
    properties = {
      count = {
        type = "number"
      }
      links = {
        type = "array",
        items = {
          type = "object",
          properties = {
            code      = { "type" : "string" },
            longUrl   = { "type" : "string" },
            createdAt = { "type" : "number" }
            archivedAt = { "type" : "number" }
          }
        }
      }
    }
  })
}


resource "aws_api_gateway_integration_response" "get_my_urls_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.get_my_urls.id
  http_method = aws_api_gateway_method.get_my_urls_get.http_method
  status_code = aws_api_gateway_method_response.get_my_urls_response_200.status_code

  depends_on = [
    aws_api_gateway_integration.get_my_urls_integration
  ]

  response_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "count": $inputRoot.Count,
  "links": [
  #foreach($item in $inputRoot.Items)
    {
      "code": "$item.code.S",
      "longUrl": "$item.longUrl.S",
      "createdAt": "$item.createdAt.N"
      "archivedAt": "$item.archivedAt.N"
    }#if($foreach.hasNext),#end
  #end
  ]
}
EOF
  }
}

resource "aws_iam_role" "get_my_urls_role" {
  name = "${local.prefix}get-my-urls-role"

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

resource "aws_iam_policy" "get_my_urls_policy" {
  name = "${local.prefix}get-my-urls-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "dynamodb:Query",
        Resource = "${aws_dynamodb_table.url_shortener.arn}/index/UserIdIndex"
      },
      {
        Effect   = "Allow",
        Action   = "dynamodb:Query",
        Resource = "${aws_dynamodb_table.url_shortener.arn}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_my_urls_attachment" {
  role       = aws_iam_role.get_my_urls_role.name
  policy_arn = aws_iam_policy.get_my_urls_policy.arn
}