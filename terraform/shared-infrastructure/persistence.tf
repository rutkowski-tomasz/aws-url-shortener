resource "aws_s3_bucket" "url_shortener_preview_storage" {
  bucket = "${local.prefix}shortened-urls-previews"
}

resource "aws_dynamodb_table" "url_shortener" {
  name         = "${local.prefix}shortened-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}
