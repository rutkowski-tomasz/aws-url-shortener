variable "environment" {
  description = "The deployment environment, restricted to 'dev' or 'prd'."
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "The environment variable must be 'dev' or 'prd'."
  }
}

variable "lambda_function_name" {
  description = "The name of the Lambda function."
  type        = string
}

variable "lambda_handler" {
  description = "The function entrypoint in your code."
  type        = string
}

variable "lambda_runtime" {
  description = "The identifier of the function's runtime."
  type        = string
}

variable "deployment_package" {
  description = "The path to the function's deployment package within the local filesystem."
  type        = string
}
