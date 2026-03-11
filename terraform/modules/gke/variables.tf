variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "The GCP region for the GKE cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be a valid GKE cluster name."
  }
}

variable "network_id" {
  description = "The VPC network ID for the cluster"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the cluster nodes"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master network"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0))
    error_message = "master_ipv4_cidr_block must be a valid CIDR block."
  }
}

variable "node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "machine_type" {
  description = "Machine type for cluster nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1

  validation {
    condition     = var.min_nodes >= 0
    error_message = "min_nodes must be >= 0."
  }
}

variable "max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5

  validation {
    condition     = var.max_nodes >= 1
    error_message = "max_nodes must be at least 1."
  }
}

variable "disk_size" {
  description = "Boot disk size in GB for nodes"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size >= 20
    error_message = "disk_size must be at least 20 GB."
  }
}

variable "preemptible" {
  description = "Use preemptible nodes (cheaper but can be interrupted)"
  type        = bool
  default     = false
}

variable "node_service_account" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "node_labels" {
  description = "Labels to apply to GKE nodes"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Taints to apply to GKE nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the GKE cluster"
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be one of: RAPID, REGULAR, STABLE."
  }
}
