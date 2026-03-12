output "service_url" {
  description = "HTTP URL of the Application Load Balancer (mirrors Cloud Run service_url)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "service_id" {
  description = "ECS service ARN"
  value       = aws_ecs_service.main.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  description = "Application Load Balancer ARN suffix for CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.main.arn
}

output "task_security_group_id" {
  description = "Security group ID for ECS tasks (use for RDS ingress rules)"
  value       = aws_security_group.tasks.id
}
