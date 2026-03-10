variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "The GCP region to deploy the Cloud Run service"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,48}[a-z0-9]$", var.service_name))
    error_message = "service_name must be a valid Cloud Run service name."
  }
}

variable "image" {
  description = "Docker image URL to deploy"
  type        = string
}

variable "port" {
  description = "Container port to expose"
  type        = number
  default     = 8080

  validation {
    condition     = var.port > 0 && var.port < 65536
    error_message = "port must be between 1 and 65535."
  }
}

variable "env_vars" {
  description = "Environment variables as key-value map"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Secret Manager-backed env vars. Map of env var name to {secret_id, version}"
  type        = map(any)
  default     = {}
}

variable "min_instances" {
  description = "Minimum number of instances (0 to scale to zero)"
  type        = number
  default     = 0

  validation {
    condition     = var.min_instances >= 0
    error_message = "min_instances must be >= 0."
  }
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

variable "cpu" {
  description = "CPU allocation (e.g., '1', '2', '4')"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory allocation (e.g., '512Mi', '1Gi', '2Gi')"
  type        = string
  default     = "512Mi"
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service"
  type        = string
}

variable "vpc_connector_id" {
  description = "VPC connector ID for VPC access (optional)"
  type        = string
  default     = null
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated invocations (public access)"
  type        = bool
  default     = false
}

variable "invoker_sa_emails" {
  description = "List of service account emails allowed to invoke the service"
  type        = list(string)
  default     = []
}

variable "health_check_path" {
  description = "HTTP path for health checks"
  type        = string
  default     = "/health"
}
