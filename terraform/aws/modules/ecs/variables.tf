variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "image" {
  description = "Container image URI"
  type        = string
}

variable "port" {
  description = "Container port to expose"
  type        = number
  default     = 8080
}

variable "env_vars" {
  description = "Environment variables to pass to the container"
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "Map of environment variable name to AWS Secrets Manager ARN"
  type        = map(string)
  default     = {}
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 3
}

variable "cpu" {
  description = "Fargate CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MB"
  type        = number
  default     = 512
}

variable "task_execution_role_arn" {
  description = "ARN of the IAM role used by ECS to pull images and write logs"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the IAM role assumed by the running container"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the Application Load Balancer"
  type        = list(string)
}

variable "health_check_path" {
  description = "HTTP path for health checks"
  type        = string
  default     = "/health"
}

variable "enable_public_access" {
  description = "Whether the ALB should be internet-facing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
