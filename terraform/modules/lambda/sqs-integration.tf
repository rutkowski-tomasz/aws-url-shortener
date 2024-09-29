locals {
  sqs_integration_count = var.sqs_queue_name != null ? 1 : 0
}

data "aws_sqs_queue" "queue" {
  count = local.sqs_integration_count
  name  = var.sqs_queue_name
}

resource "aws_iam_role_policy" "sqs_policy" {
  count = local.sqs_integration_count
  name  = "${var.lambda_function_name}-sqs-policy"
  role  = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.aws_sqs_queue.queue[0].arn
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_mapping" {
  count = local.sqs_integration_count
  event_source_arn = data.aws_sqs_queue.queue[0].arn
  function_name    = aws_lambda_function.lambda.function_name
  enabled          = true
  maximum_batching_window_in_seconds = 5

  scaling_config {
    maximum_concurrency = var.reserved_concurrent_executions
  }

  depends_on = [aws_iam_role_policy.sqs_policy]
}


