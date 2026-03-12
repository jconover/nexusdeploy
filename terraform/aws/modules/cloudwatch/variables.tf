variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "notification_email" {
  description = "Email address for alarm notifications"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name used for metric dimensions"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name used for metric dimensions"
  type        = string
  default     = ""
}

variable "ecs_log_group_name" {
  description = "CloudWatch log group name for ECS service log metric filters. Set to null to skip filter creation."
  type        = string
  default     = null
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used as the LoadBalancer dimension for 5xx metric alarm. Set to null to skip alarm creation."
  type        = string
  default     = null
}

variable "health_check_targets" {
  description = "Map of Route53 health check targets. Each key is a logical name; each value must include fqdn, port, type, and path."
  type = map(object({
    fqdn = string
    port = number
    type = string
    path = string
  }))
  default = {}
}

variable "alert_thresholds" {
  description = <<-EOT
    Map of alert thresholds. Keys:
    - cpu_percent: ECS CPU utilization % to trigger alarm (default: 80)
    - memory_percent: ECS memory utilization % to trigger alarm (default: 80)
    - error_count: ALB 5xx count to trigger alarm (default: 10)
  EOT
  type        = map(number)
  default = {
    cpu_percent    = 80
    memory_percent = 80
    error_count    = 10
  }
}

variable "tags" {
  description = "Map of tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}
