output "notification_channel_ids" {
  description = "List of notification channel IDs"
  value       = local.notification_channels
}

output "email_notification_channel_id" {
  description = "The email notification channel ID"
  value       = google_monitoring_notification_channel.email.id
}

output "slack_notification_channel_id" {
  description = "The Slack notification channel ID (null if not configured)"
  value       = var.slack_webhook_url != null ? google_monitoring_notification_channel.slack[0].id : null
  sensitive   = true
}

output "dashboard_id" {
  description = "The monitoring dashboard ID"
  value       = google_monitoring_dashboard.main.id
}

output "alert_policy_ids" {
  description = "Map of alert policy name to ID"
  value = {
    cpu_high        = google_monitoring_alert_policy.cpu_high.id
    error_rate_high = google_monitoring_alert_policy.error_rate_high.id
    memory_high     = google_monitoring_alert_policy.memory_high.id
  }
}

output "uptime_check_ids" {
  description = "Map of uptime check name to ID"
  value = {
    for k, v in google_monitoring_uptime_check_config.checks : k => v.id
  }
}
