variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ── VPC ─────────────────────────────────────────────────────────────────────
variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "nexusdeploy-dev"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.10.0.0/24"
}

variable "pods_cidr" {
  description = "GKE pods secondary range CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "GKE services secondary range CIDR"
  type        = string
  default     = "10.30.0.0/20"
}

# ── GKE ─────────────────────────────────────────────────────────────────────
variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "nexusdeploy-dev"
}

variable "gke_node_count" {
  description = "Number of GKE nodes per zone"
  type        = number
  default     = 1
}

variable "gke_machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-medium"
}

# ── Cloud SQL ────────────────────────────────────────────────────────────────
variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "nexusdeploy-dev-db"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Default database name"
  type        = string
  default     = "nexusdeploy"
}

# ── Cloud Run ────────────────────────────────────────────────────────────────
variable "cloud_run_service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "nexusdeploy-api-dev"
}

variable "cloud_run_image" {
  description = "Container image URL for Cloud Run"
  type        = string
}

variable "cloud_run_min_instances" {
  description = "Minimum Cloud Run instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 3
}

# ── Artifact Registry / Docker ───────────────────────────────────────────────
variable "artifact_registry_repo" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "nexusdeploy-dev"
}

# ── Vertex AI ────────────────────────────────────────────────────────────────
variable "vertex_region" {
  description = "Vertex AI region (must support the desired models)"
  type        = string
  default     = "us-central1"
}

# ── Cloud Functions ───────────────────────────────────────────────────────────
variable "functions_source_bucket" {
  description = "GCS bucket containing Cloud Functions source zips"
  type        = string
}

# ── Notifications ────────────────────────────────────────────────────────────
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
