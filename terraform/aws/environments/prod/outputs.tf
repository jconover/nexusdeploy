###############################################################################
# Outputs
###############################################################################

# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the production VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the production VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "availability_zones" {
  description = "Availability zones in use"
  value       = module.vpc.availability_zones
}

# ── IAM ───────────────────────────────────────────────────────────────────────
output "iam_role_arns" {
  description = "Map of IAM role key to ARN"
  value       = module.iam.role_arns
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_id" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_id
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.cluster_oidc_issuer_url
}

# ── ECS ───────────────────────────────────────────────────────────────────────
output "ecs_service_url" {
  description = "ECS service URL (ALB DNS)"
  value       = module.ecs.service_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.ecs.alb_dns_name
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS instance hostname"
  value       = module.rds.address
  sensitive   = true
}

output "rds_database_name" {
  description = "Name of the database"
  value       = module.rds.database_name
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master password"
  value       = module.rds.master_user_secret_arn
  sensitive   = true
}

# ── Lambda ────────────────────────────────────────────────────────────────────
output "lambda_function_arn" {
  description = "ARN of the Lambda event processor function"
  value       = module.lambda.function_arn
}

output "lambda_sns_topic_arn" {
  description = "ARN of the SNS topic that triggers the Lambda function"
  value       = module.lambda.sns_topic_arn
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
output "cloudwatch_sns_topic_arn" {
  description = "ARN of the CloudWatch alerts SNS topic"
  value       = module.cloudwatch.sns_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch monitoring dashboard"
  value       = module.cloudwatch.dashboard_name
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
output "secret_arns" {
  description = "Map of secret key to ARN"
  value       = module.secrets_manager.secret_arns
}

# ── SageMaker ─────────────────────────────────────────────────────────────────
output "sagemaker_endpoint_name" {
  description = "Name of the SageMaker inference endpoint"
  value       = module.sagemaker.endpoint_name
}

output "sagemaker_endpoint_arn" {
  description = "ARN of the SageMaker inference endpoint"
  value       = module.sagemaker.endpoint_arn
}

output "sagemaker_feature_group_name" {
  description = "Name of the SageMaker Feature Store feature group"
  value       = module.sagemaker.feature_group_name
}
