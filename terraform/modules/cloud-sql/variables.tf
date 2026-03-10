variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "The GCP region for the Cloud SQL instance"
  type        = string
}

variable "network_id" {
  description = "The VPC network ID for private IP"
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,95}$", var.instance_name))
    error_message = "instance_name must start with a letter, contain only lowercase letters, digits, or hyphens."
  }
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "app"
}

variable "database_user" {
  description = "Name of the database user"
  type        = string
  default     = "app"
}

variable "tier" {
  description = "Machine tier for Cloud SQL (e.g., db-f1-micro, db-custom-2-7680)"
  type        = string
  default     = "db-custom-2-7680"
}

variable "availability_type" {
  description = "Availability type: ZONAL or REGIONAL (HA)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance"
  type        = bool
  default     = true
}
