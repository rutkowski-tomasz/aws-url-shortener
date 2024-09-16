data "terraform_remote_state" "shared_infrastructure" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "us-cicd"
    key    = "terraform/shared-infrastructure"
    region = "eu-central-1"
  }
}
