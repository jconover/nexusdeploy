variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "slack_auth_token" {
  description = "Slack auth token for notification channel (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "monitored_services" {
  description = "List of service names to monitor"
  type        = list(string)
  default     = []
}

variable "uptime_check_hosts" {
  description = <<-EOT
    List of hosts to perform uptime checks on. Each entry supports:
    - name: Unique name for the check
    - host: Hostname to check
    - path: HTTP path (default: /health)
    - port: Port (default: 443)
    - use_ssl: Whether to use SSL (default: true)
    - validate_ssl: Whether to validate SSL cert (default: true)
  EOT
  type        = list(any)
  default     = []
}

variable "alert_thresholds" {
  description = <<-EOT
    Map of alert thresholds. Keys:
    - cpu_percent: CPU utilization fraction (default: 0.8)
    - memory_percent: Memory utilization % (default: 85)
    - error_rate_rps: 5xx error rate in req/s (default: 5)
  EOT
  type        = map(number)
  default     = {}
}
