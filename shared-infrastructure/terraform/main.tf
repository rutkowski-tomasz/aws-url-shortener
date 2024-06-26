resource "aws_dynamodb_table" "url_shortener" {
  name         = "${local.prefix}shortened-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }
}
