variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "secrets" {
  description = <<-EOT
    Map of secrets to create. Each key is the secret_id. Each value supports:
    - value: The secret data (optional; use null to create a secret without a version)
    - labels: Optional map of labels
  EOT
  type        = map(any)
  default     = {}
}

variable "accessor_sa_emails" {
  description = "List of service account emails to grant secretmanager.secretAccessor role on all secrets"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.accessor_sa_emails : can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$", e))])
    error_message = "All entries must be valid GCP service account email addresses."
  }
}
