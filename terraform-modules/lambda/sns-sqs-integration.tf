locals {
  sns_sqs_integration_count = var.sns_topic_name != null ? 1 : 0
}

data "aws_sns_topic" "topic" {
  count = local.sns_sqs_integration_count
  name  = var.sns_topic_name
}

resource "aws_sqs_queue" "dlq" {
  count = local.sns_sqs_integration_count
  name  = "${var.sns_topic_name}-${var.lambda_function_name}-dlq"
}

resource "aws_sqs_queue" "queue" {
  count = local.sns_sqs_integration_count
  name  = "${var.sns_topic_name}-${var.lambda_function_name}-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn,
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "queue_policy" {
  count     = local.sns_sqs_integration_count
  queue_url = aws_sqs_queue.queue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.queue[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = data.aws_sns_topic.topic[0].arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "subscription" {
  count     = local.sns_sqs_integration_count
  topic_arn = data.aws_sns_topic.topic[0].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue[0].arn
}

resource "aws_iam_role_policy" "lambda_sqs_policy" {
  count = local.sns_sqs_integration_count
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
        Resource = aws_sqs_queue.queue[0].arn
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  count            = local.sns_sqs_integration_count
  event_source_arn = aws_sqs_queue.queue[0].arn
  function_name    = aws_lambda_function.lambda.function_name
  enabled          = true
  batch_size       = 10

  depends_on = [aws_iam_role_policy.lambda_sqs_policy]
}


