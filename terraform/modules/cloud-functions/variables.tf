variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "The GCP region to deploy the Cloud Function"
  type        = string
}

variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.function_name))
    error_message = "function_name must be a valid resource name."
  }
}

variable "runtime" {
  description = "Runtime for the Cloud Function (e.g., nodejs20, python311, go121)"
  type        = string
  default     = "nodejs20"
}

variable "entry_point" {
  description = "Name of the function to execute"
  type        = string
}

variable "source_bucket" {
  description = "GCS bucket containing the function source code"
  type        = string
}

variable "source_object" {
  description = "GCS object (zip file) containing the function source code"
  type        = string
}

variable "event_trigger_topic" {
  description = "Pub/Sub topic name to trigger the function"
  type        = string
}

variable "create_trigger_topic" {
  description = "Whether to create the Pub/Sub trigger topic (false to use existing)"
  type        = bool
  default     = true
}

variable "service_account_email" {
  description = "Service account email for the Cloud Function"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "vpc_connector" {
  description = "VPC connector ID for VPC access (optional)"
  type        = string
  default     = null
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10

  validation {
    condition     = var.max_instances >= 1
    error_message = "max_instances must be at least 1."
  }
}

variable "memory" {
  description = "Available memory (e.g., '256M', '512M', '1G')"
  type        = string
  default     = "256M"
}

variable "timeout_seconds" {
  description = "Function timeout in seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 3600
    error_message = "timeout_seconds must be between 1 and 3600."
  }
}

variable "retry_on_failure" {
  description = "Whether to retry the function on failure"
  type        = bool
  default     = false
}
