variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per availability zone)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (one per availability zone)"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s) for private subnet egress"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway shared across all AZs (cost savings for dev)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
