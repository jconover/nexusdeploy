variable "endpoint_name" {
  description = "Name for the SageMaker endpoint"
  type        = string
}

variable "model_name" {
  description = "Display name for the SageMaker model"
  type        = string
}

variable "instance_type" {
  description = "SageMaker instance type for the endpoint"
  type        = string
  default     = "ml.t2.medium"
}

variable "min_instance_count" {
  description = "Minimum number of instances for the endpoint"
  type        = number
  default     = 1
}

variable "max_instance_count" {
  description = "Maximum number of instances for auto-scaling"
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "IAM role ARN for SageMaker to assume when accessing resources"
  type        = string
}

variable "model_image_uri" {
  description = "ECR image URI for the model container"
  type        = string
}

variable "model_data_url" {
  description = "S3 path to model artifacts (optional)"
  type        = string
  default     = null
}

variable "vpc_config" {
  description = "VPC configuration for the SageMaker model (optional)"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "create_feature_group" {
  description = "Whether to create a SageMaker Feature Store feature group"
  type        = bool
  default     = false
}

variable "feature_group_name" {
  description = "Name for the SageMaker Feature Store feature group"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all SageMaker resources"
  type        = map(string)
  default     = {}
}
