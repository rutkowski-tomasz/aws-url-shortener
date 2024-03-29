terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "trutkowski"

    workspaces {
      name = "shorten-url-lambda"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
}
