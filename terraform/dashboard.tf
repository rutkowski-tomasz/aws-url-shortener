resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}main-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      // Lambda Functions
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${local.prefix}dynamodb-stream-lambda"],
            ["...", "${local.prefix}generate-preview-lambda"],
            ["...", "${local.prefix}get-preview-url-lambda"],
            ["...", "${local.prefix}get-url-lambda"],
            ["...", "${local.prefix}push-notification-lambda"],
            ["...", "${local.prefix}shorten-url-lambda"],
            ["...", "${local.prefix}delete-url-lambda"],
            ["...", "${local.prefix}websocket-authorizer-lambda"],
            ["...", "${local.prefix}websocket-manager-lambda"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda: Invocations"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "${local.prefix}dynamodb-stream-lambda"],
            ["...", "${local.prefix}generate-preview-lambda"],
            ["...", "${local.prefix}get-preview-url-lambda"],
            ["...", "${local.prefix}get-url-lambda"],
            ["...", "${local.prefix}push-notification-lambda"],
            ["...", "${local.prefix}shorten-url-lambda"],
            ["...", "${local.prefix}delete-url-lambda"],
            ["...", "${local.prefix}websocket-authorizer-lambda"],
            ["...", "${local.prefix}websocket-manager-lambda"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda: Errors"
          period  = 3600
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${local.prefix}dynamodb-stream-lambda"],
            ["...", "${local.prefix}generate-preview-lambda"],
            ["...", "${local.prefix}get-preview-url-lambda"],
            ["...", "${local.prefix}get-url-lambda"],
            ["...", "${local.prefix}push-notification-lambda"],
            ["...", "${local.prefix}shorten-url-lambda"],
            ["...", "${local.prefix}delete-url-lambda"],
            ["...", "${local.prefix}websocket-authorizer-lambda"],
            ["...", "${local.prefix}websocket-manager-lambda"]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "Lambda: Duration"
          period = 3600
          stat   = "Maximum"
        }
      },

      // API Gateway
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${local.prefix}url-shortener-api", { "color": "#2ca02c" }],
            [".", "4XXError", ".", ".", { "color": "#ff7f0e" }],
            [".", "5XXError", ".", ".", { "color": "#d62728" }]
          ]
          view   = "timeSeries"
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "API Gateway: Request Count and Errors"
          period = 3600
        }
      },

      // DynamoDB
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "${local.prefix}shortened-urls"],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "DynamoDB: Consumed Capacity Units"
          period = 3600
          stat   = "Sum"
        }
      },
    ]
  })
}
