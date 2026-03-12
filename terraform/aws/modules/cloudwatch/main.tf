resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.project_name}-cpu-utilization"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alert_thresholds["cpu_percent"]
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${var.project_name}-memory-utilization"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alert_thresholds["memory_percent"]
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.alb_arn_suffix != null ? 1 : 0

  alarm_name          = "${var.project_name}-alb-5xx-errors"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alert_thresholds["error_count"]
  evaluation_periods  = 2
  period              = 300
  statistic           = "Sum"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  count = var.ecs_log_group_name != null && var.ecs_log_group_name != "" ? 1 : 0

  name           = "${var.project_name}-app-errors"
  log_group_name = var.ecs_log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name      = "AppErrorCount"
    namespace = "Custom/${var.project_name}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "http_500" {
  count = var.ecs_log_group_name != null && var.ecs_log_group_name != "" ? 1 : 0

  name           = "${var.project_name}-http-500"
  log_group_name = var.ecs_log_group_name
  pattern        = "\"HTTP/1.1\\\" 500\""

  metric_transformation {
    name      = "Http500Count"
    namespace = "Custom/${var.project_name}"
    value     = "1"
  }
}

resource "aws_route53_health_check" "targets" {
  for_each = var.health_check_targets

  fqdn              = each.value.fqdn
  port              = each.value.port
  type              = each.value.type
  resource_path     = each.value.path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU Utilization"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS Memory Utilization"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB 5xx Errors"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix != null ? var.alb_arn_suffix : ""]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Application Error Count"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["Custom/${var.project_name}", "AppErrorCount"]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}
