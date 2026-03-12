variable "secrets" {
  description = <<-EOT
    Map of secrets to create. Each key is the secret name. Each value supports:
    - description: Optional description for the secret
    - value: The secret data (optional; use null to create a secret without a version)
    - tags: Optional map of tags to apply to this specific secret
  EOT
  type = map(object({
    description = optional(string, "")
    value       = optional(string, null)
    tags        = optional(map(string), {})
  }))
  default = {}

  sensitive = false
}

variable "recovery_window_in_days" {
  description = "Number of days before a deleted secret is permanently removed. Use 0 for immediate deletion (dev), or 7-30 for production."
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (immediate deletion) or between 7 and 30 inclusive."
  }
}

variable "kms_key_id" {
  description = "Optional ARN of a custom KMS key to use for encrypting secrets. If null, the AWS-managed key is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
