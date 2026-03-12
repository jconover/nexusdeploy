variable "roles" {
  description = "Map of role name to role configuration"
  type = map(object({
    description             = string
    assume_role_policy      = string
    managed_policy_arns     = optional(list(string), [])
    create_instance_profile = optional(bool, false)
  }))
}

variable "custom_policies" {
  description = "Map of policy name to custom IAM policy configuration"
  type = map(object({
    description     = string
    policy_document = string
    role_keys       = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
