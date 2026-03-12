variable "instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "database_user" {
  description = "Master username for the database"
  type        = string
  default     = "nexusdeploy"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.2"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GiB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the instance"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ARN of the KMS key to use for storage encryption. Uses the default RDS key if null."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the RDS security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (should be private subnets)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the RDS instance on port 5432"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
