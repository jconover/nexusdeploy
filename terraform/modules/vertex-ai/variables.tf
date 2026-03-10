variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "The GCP region for Vertex AI resources"
  type        = string
}

variable "endpoint_name" {
  description = "Name of the Vertex AI endpoint"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.endpoint_name))
    error_message = "endpoint_name must be a valid resource name."
  }
}

variable "model_display_name" {
  description = "Display name for the model endpoint"
  type        = string
}

variable "machine_type" {
  description = "Machine type for model serving (e.g., n1-standard-4)"
  type        = string
  default     = "n1-standard-4"
}

variable "min_replica_count" {
  description = "Minimum number of replicas for serving"
  type        = number
  default     = 1

  validation {
    condition     = var.min_replica_count >= 1
    error_message = "min_replica_count must be at least 1."
  }
}

variable "max_replica_count" {
  description = "Maximum number of replicas for serving"
  type        = number
  default     = 3

  validation {
    condition     = var.max_replica_count >= 1
    error_message = "max_replica_count must be at least 1."
  }
}

variable "network" {
  description = "VPC network for private endpoint (optional, full resource URI)"
  type        = string
  default     = null
}

variable "create_featurestore" {
  description = "Whether to create a Vertex AI Feature Store"
  type        = bool
  default     = false
}

variable "featurestore_node_count" {
  description = "Fixed node count for Feature Store online serving"
  type        = number
  default     = 1

  validation {
    condition     = var.featurestore_node_count >= 1
    error_message = "featurestore_node_count must be at least 1."
  }
}
