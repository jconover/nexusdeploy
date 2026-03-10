variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
variable "network_name" {
  type    = string
  default = "nexusdeploy-prod"
}

variable "subnet_cidr" {
  type    = string
  default = "10.12.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.22.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.32.0.0/20"
}

# ── GKE ──────────────────────────────────────────────────────────────────────
variable "cluster_name" {
  type    = string
  default = "nexusdeploy-prod"
}

variable "gke_node_count" {
  type    = number
  default = 3
}

variable "gke_machine_type" {
  type    = string
  default = "e2-standard-4"
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
variable "db_instance_name" {
  type    = string
  default = "nexusdeploy-prod-db"
}

variable "db_tier" {
  type    = string
  default = "db-custom-4-15360"
}

variable "db_name" {
  type    = string
  default = "nexusdeploy"
}

# ── Cloud Run ─────────────────────────────────────────────────────────────────
variable "cloud_run_service_name" {
  type    = string
  default = "nexusdeploy-api-prod"
}

variable "cloud_run_image" {
  type = string
}

variable "cloud_run_min_instances" {
  type    = number
  default = 2
}

variable "cloud_run_max_instances" {
  type    = number
  default = 20
}

# ── Cloud Functions ───────────────────────────────────────────────────────────
variable "functions_source_bucket" {
  description = "GCS bucket containing Cloud Functions source zips"
  type        = string
}

# ── Vertex AI ─────────────────────────────────────────────────────────────────
variable "vertex_region" {
  type    = string
  default = "us-central1"
}

# ── Notifications ─────────────────────────────────────────────────────────────
variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (optional)"
  type        = string
  default     = null
  sensitive   = true
}
