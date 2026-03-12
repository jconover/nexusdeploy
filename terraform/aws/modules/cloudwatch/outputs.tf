output "sns_topic_arn" {
  description = "ARN of the alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch monitoring dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarm_arns" {
  description = "Map of alarm name to ARN for cpu, memory, and alb_5xx alarms"
  value = {
    cpu     = aws_cloudwatch_metric_alarm.cpu.arn
    memory  = aws_cloudwatch_metric_alarm.memory.arn
    alb_5xx = var.alb_arn_suffix != null ? aws_cloudwatch_metric_alarm.alb_5xx[0].arn : null
  }
}

output "health_check_ids" {
  description = "Map of health check logical name to Route53 health check ID"
  value       = { for k, v in aws_route53_health_check.targets : k => v.id }
}
