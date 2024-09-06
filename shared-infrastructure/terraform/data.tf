data "terraform_remote_state" "shorten_url_lambda_state" {
  backend = "remote"

  config = {
    organization = "trutkowski"

    workspaces = {
      name = "us-${var.environment}-shorten-url-lambda"
    }
  }
}

data "terraform_remote_state" "get_url_lambda_state" {
  backend = "remote"

  config = {
    organization = "trutkowski"

    workspaces = {
      name = "us-${var.environment}-get-url-lambda"
    }
  }
}

data "terraform_remote_state" "dynamodb_stream_lambda_state" {
  backend = "remote"

  config = {
    organization = "trutkowski"

    workspaces = {
      name = "us-${var.environment}-dynamodb-stream-lambda"
    }
  }
}

data "terraform_remote_state" "get_preview_url_lambda_state" {
  backend = "remote"

  config = {
    organization = "trutkowski"

    workspaces = {
      name = "us-${var.environment}-get-preview-url-lambda"
    }
  }
}

data "aws_region" "current" {}
