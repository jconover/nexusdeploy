variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "nexusdeploy"
}
