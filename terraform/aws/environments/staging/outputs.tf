output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA configuration"
  value       = module.eks.cluster_oidc_issuer_url
}

output "ecs_service_url" {
  description = "ECS service URL via Application Load Balancer"
  value       = module.ecs.service_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "rds_endpoint" {
  description = "RDS instance connection endpoint (host:port)"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS instance hostname"
  value       = module.rds.address
  sensitive   = true
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master password"
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "iam_role_arns" {
  description = "Map of IAM role names to ARNs"
  value       = module.iam.role_arns
}

output "secret_arns" {
  description = "Map of Secrets Manager secret logical keys to ARNs"
  value       = module.secrets_manager.secret_arns
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "lambda_sns_topic_arn" {
  description = "SNS topic ARN that triggers the Lambda function"
  value       = module.lambda.sns_topic_arn
}

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name"
  value       = module.sagemaker.endpoint_name
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch monitoring dashboard name"
  value       = module.cloudwatch.dashboard_name
}

output "cloudwatch_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value       = module.cloudwatch.sns_topic_arn
}
