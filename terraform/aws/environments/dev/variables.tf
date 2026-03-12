variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "nexusdeploy"
}

# ── ECS ──────────────────────────────────────────────────────────────────────
variable "ecs_image" {
  description = "Container image URI for the ECS service"
  type        = string
}

# ── Lambda ───────────────────────────────────────────────────────────────────
variable "lambda_source_bucket" {
  description = "S3 bucket containing Lambda deployment packages"
  type        = string
}

# ── SageMaker ────────────────────────────────────────────────────────────────
variable "sagemaker_image_uri" {
  description = "ECR image URI for the SageMaker model container"
  type        = string
}

# ── Notifications ─────────────────────────────────────────────────────────────
variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}
