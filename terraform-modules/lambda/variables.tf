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

variable "lambda_memory_size" {
  description = "Amount of memory assigned to lambda at runtime (MB)."
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Amount of time lambda has to run (s)."
  type        = number
  default     = 3
}

variable "lambda_layers" {
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.lambda_layers) <= 5
    error_message = "A maximum of 5 Lambda Layers can be specified."
  }
}

variable "custom_policy_statements" {
  description = "List of custom IAM policy statements to be added to the Lambda execution role."
  type = list(object({
    Effect    = string
    Action    = string
    Resource  = string
  }))
  default = []
}

variable "pack_dependencies" {
  description = "Whether to pack dependencies (node_modules) into the deployment package"
  type        = bool
  default     = false
}

