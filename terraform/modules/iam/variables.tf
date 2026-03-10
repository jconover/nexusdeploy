variable "project_id" {
  description = "The GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "service_accounts" {
  description = <<-EOT
    Map of service accounts to create. Each entry supports:
    - display_name: Human-readable name (required)
    - description: Optional description
    - roles: List of IAM roles to grant at project level
    - custom_role_ids: List of custom role IDs from custom_roles variable
    - workload_identity_namespace: K8s namespace/SA for workload identity (e.g., "default/my-sa")
  EOT
  type        = map(any)
  default     = {}
}

variable "custom_roles" {
  description = <<-EOT
    List of custom IAM roles to create. Each entry requires:
    - role_id: Unique role ID within the project
    - title: Human-readable role title
    - permissions: List of IAM permissions
    - description: Optional description
  EOT
  type = list(object({
    role_id     = string
    title       = string
    permissions = list(string)
    description = optional(string, "")
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.custom_roles : length(r.permissions) > 0])
    error_message = "Each custom role must have at least one permission."
  }
}
