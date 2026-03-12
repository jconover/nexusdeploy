variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Lambda handler in module.function format"
  type        = string
  default     = "main.handler"
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the deployment package"
  type        = string
}

variable "sns_topic_name" {
  description = "SNS topic name for Lambda event trigger"
  type        = string
}

variable "create_sns_topic" {
  description = "Create the SNS topic (true) or reference an existing topic by name (false)"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "memory_size" {
  description = "Amount of memory in MB allocated to the Lambda function"
  type        = number
  default     = 256

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent execution limit. -1 means unreserved."
  type        = number
  default     = -1
}

variable "vpc_config" {
  description = "VPC configuration for the Lambda function. Set to null to run outside a VPC."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}
