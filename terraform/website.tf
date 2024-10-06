resource "aws_s3_bucket" "website_bucket" {
  bucket = "${local.prefix}website-bucket"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      },
    ]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "../web/index.html"
  content_type = "text/html"
  etag         = filemd5("../web/index.html")
}

resource "aws_s3_object" "main_js" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "main.js"
  source       = "../web/main.js"
  content_type = "application/javascript"
  etag         = filemd5("../web/main.js")
}

output "website_url" {
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
  description = "S3 Static Website URL"
}
