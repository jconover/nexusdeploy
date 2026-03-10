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
  default     = "staging"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
variable "network_name" {
  type    = string
  default = "nexusdeploy-staging"
}

variable "subnet_cidr" {
  type    = string
  default = "10.11.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.21.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.31.0.0/20"
}

# ── GKE ──────────────────────────────────────────────────────────────────────
variable "cluster_name" {
  type    = string
  default = "nexusdeploy-staging"
}

variable "gke_node_count" {
  type    = number
  default = 2
}

variable "gke_machine_type" {
  type    = string
  default = "e2-standard-2"
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
variable "db_instance_name" {
  type    = string
  default = "nexusdeploy-staging-db"
}

variable "db_tier" {
  type    = string
  default = "db-g1-small"
}

variable "db_name" {
  type    = string
  default = "nexusdeploy"
}

# ── Cloud Run ─────────────────────────────────────────────────────────────────
variable "cloud_run_service_name" {
  type    = string
  default = "nexusdeploy-api-staging"
}

variable "cloud_run_image" {
  type = string
}

variable "cloud_run_min_instances" {
  type    = number
  default = 1
}

variable "cloud_run_max_instances" {
  type    = number
  default = 5
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
