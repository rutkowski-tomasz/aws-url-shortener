resource "aws_s3_bucket" "preview_storage" {
  bucket = "${local.prefix}preview-storage"
}

resource "aws_sns_topic" "preview_generated" {
  name           = "${local.prefix}preview-generated"
  tracing_config = "Active"
  policy         = <<POLICY
  {
    "Version":"2012-10-17",
    "Statement":
    [
      {
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:${local.prefix}preview-generated",
        "Condition":
        {
          "ArnLike": { "aws:SourceArn": "${aws_s3_bucket.preview_storage.arn}" }
        }
    }]
  }
  POLICY
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.preview_storage.id

  topic {
    topic_arn = aws_sns_topic.preview_generated.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}
