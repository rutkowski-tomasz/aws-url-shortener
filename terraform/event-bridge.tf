resource "aws_cloudwatch_event_bus" "url_shortener" {
    name = "${local.prefix}url-shortener"
}

# Scheduler
resource "aws_iam_role" "scheduler_role" {
    name = "${local.prefix}scheduler-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "scheduler.amazonaws.com"
                }
                Condition = {
                    StringEquals = {
                        "aws:SourceAccount" = data.aws_caller_identity.current.account_id
                    }
                }
            }
        ]
    })
}

resource "aws_iam_role_policy" "scheduler_policy" {
    name = "${local.prefix}scheduler-policy"
    role = aws_iam_role.scheduler_role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = "events:PutEvents"
                Resource = aws_cloudwatch_event_bus.url_shortener.arn
            }
        ]
    })
}

# Log everything to CloudWatch log group
resource "aws_cloudwatch_event_rule" "log_everything" {
    name = "${local.prefix}log-everything"
    event_bus_name = aws_cloudwatch_event_bus.url_shortener.name
    event_pattern = jsonencode({
        source = ["url-shortener"]
    })
}

resource "aws_cloudwatch_event_target" "log_everything_target" {
    rule = aws_cloudwatch_event_rule.log_everything.name
    event_bus_name = aws_cloudwatch_event_bus.url_shortener.name
    arn = "${aws_cloudwatch_log_group.log_everything.arn}:*"
}

resource "aws_cloudwatch_log_group" "log_everything" {
    name = "/aws/events/${local.prefix}events"
}

# Archive in CloudWatch Bus Archive
resource "aws_cloudwatch_event_archive" "archive" {
    name = "${local.prefix}events-archive"
    event_source_arn = aws_cloudwatch_event_bus.url_shortener.arn
    retention_days = 30
}

resource "aws_cloudwatch_event_rule" "shortener_url_delete_command" {
    name = "${local.prefix}shortener-url-delete-command"
    event_bus_name = aws_cloudwatch_event_bus.url_shortener.name
    event_pattern = jsonencode({
        detail_type = ["DeleteShortenedUrl"]
        source = ["url-shortener"]
    })
}

resource "aws_cloudwatch_event_target" "shortener_url_delete_command_target" {
    rule = aws_cloudwatch_event_rule.shortener_url_delete_command.name
    event_bus_name = aws_cloudwatch_event_bus.url_shortener.name
    arn = aws_sqs_queue.shortener_url_delete_command.arn
}

resource "aws_sqs_queue" "shortener_url_delete_command" {
    name = "${local.prefix}delete-url-command"
    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.dlq.arn,
        maxReceiveCount     = 3
    })
}

resource "aws_sqs_queue" "dlq" {
    name = "${local.prefix}delete-url-command-dlq"
}