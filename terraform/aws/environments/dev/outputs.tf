# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "vpc_cidr_block" {
  value       = module.vpc.vpc_cidr_block
  description = "VPC CIDR block"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "List of public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "List of private subnet IDs"
}

# ── IAM ───────────────────────────────────────────────────────────────────────
output "iam_role_arns" {
  value       = module.iam.role_arns
  description = "Map of IAM role names to ARNs"
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API server endpoint"
  sensitive   = true
}

output "eks_cluster_ca_certificate" {
  value       = module.eks.cluster_ca_certificate
  description = "EKS cluster CA certificate (base64-encoded)"
  sensitive   = true
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_address" {
  value       = module.rds.address
  description = "RDS instance hostname"
  sensitive   = true
}

output "rds_port" {
  value       = module.rds.port
  description = "RDS instance port"
}

output "rds_database_name" {
  value       = module.rds.database_name
  description = "RDS database name"
}

output "rds_instance_identifier" {
  value       = module.rds.instance_identifier
  description = "RDS instance identifier"
}

# ── ECS ───────────────────────────────────────────────────────────────────────
output "ecs_service_url" {
  value       = module.ecs.service_url
  description = "ECS service URL (ALB DNS name)"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = module.ecs.service_name
  description = "ECS service name"
}

output "ecs_alb_dns_name" {
  value       = module.ecs.alb_dns_name
  description = "Application Load Balancer DNS name"
}

# ── Lambda ────────────────────────────────────────────────────────────────────
output "lambda_function_arn" {
  value       = module.lambda.function_arn
  description = "Lambda function ARN"
}

output "lambda_function_name" {
  value       = module.lambda.function_name
  description = "Lambda function name"
}

output "lambda_sns_topic_arn" {
  value       = module.lambda.sns_topic_arn
  description = "SNS topic ARN triggering the Lambda function"
}

# ── SageMaker ─────────────────────────────────────────────────────────────────
output "sagemaker_endpoint_name" {
  value       = module.sagemaker.endpoint_name
  description = "SageMaker endpoint name"
}

output "sagemaker_endpoint_arn" {
  value       = module.sagemaker.endpoint_arn
  description = "SageMaker endpoint ARN"
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
output "secret_arns" {
  value       = module.secrets_manager.secret_arns
  description = "Map of secret names to ARNs"
  sensitive   = true
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
output "cloudwatch_dashboard_name" {
  value       = module.cloudwatch.dashboard_name
  description = "CloudWatch dashboard name"
}

output "cloudwatch_alarm_arns" {
  value       = module.cloudwatch.alarm_arns
  description = "List of CloudWatch alarm ARNs"
}
