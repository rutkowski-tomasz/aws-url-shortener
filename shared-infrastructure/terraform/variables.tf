variable "environment" {
  description = "The deployment environment (e.g., dev, prd)"
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "The environment variable must be one of: dev, prd."
  }
}
