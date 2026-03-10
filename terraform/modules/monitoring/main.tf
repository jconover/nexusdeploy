resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Email Notification"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_notification_channel" "slack" {
  count = var.slack_webhook_url != null ? 1 : 0

  project      = var.project_id
  display_name = "Slack Notification"
  type         = "slack"

  labels = {
    url = var.slack_webhook_url
  }

  sensitive_labels {
    auth_token = var.slack_auth_token != null ? var.slack_auth_token : ""
  }
}

locals {
  notification_channels = concat(
    [google_monitoring_notification_channel.email.id],
    var.slack_webhook_url != null ? [google_monitoring_notification_channel.slack[0].id] : []
  )
}

resource "google_monitoring_alert_policy" "cpu_high" {
  project      = var.project_id
  display_name = "High CPU Utilization"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization above threshold"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = lookup(var.alert_thresholds, "cpu_percent", 0.8)

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "error_rate_high" {
  project      = var.project_id
  display_name = "High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Error rate above threshold"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = lookup(var.alert_thresholds, "error_rate_rps", 5)

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "memory_high" {
  project      = var.project_id
  display_name = "High Memory Utilization"
  combiner     = "OR"

  conditions {
    display_name = "Memory utilization above threshold"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/memory/percent_used\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = lookup(var.alert_thresholds, "memory_percent", 85)

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_uptime_check_config" "checks" {
  for_each = { for h in var.uptime_check_hosts : h.name => h }

  project      = var.project_id
  display_name = "Uptime check: ${each.value.name}"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = lookup(each.value, "path", "/health")
    port           = lookup(each.value, "port", 443)
    use_ssl        = lookup(each.value, "use_ssl", true)
    validate_ssl   = lookup(each.value, "validate_ssl", true)
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }
}

resource "google_logging_metric" "error_count" {
  project = var.project_id
  name    = "application_error_count"
  filter  = "severity >= ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    display_name = "Application Error Count"
  }
}

resource "google_logging_metric" "http_500_count" {
  project = var.project_id
  name    = "http_500_error_count"
  filter  = "httpRequest.status >= 500 AND httpRequest.status < 600"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    display_name = "HTTP 500 Error Count"
  }
}

resource "google_monitoring_dashboard" "main" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "Application Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                    aggregation = {
                      perSeriesAligner   = "ALIGN_MEAN"
                      alignmentPeriod    = "60s"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
                    aggregation = {
                      perSeriesAligner   = "ALIGN_RATE"
                      alignmentPeriod    = "60s"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Application Errors"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/application_error_count\""
                    aggregation = {
                      perSeriesAligner   = "ALIGN_RATE"
                      alignmentPeriod    = "60s"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
