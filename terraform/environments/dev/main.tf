###############################################################################
# Dev environment – composes all NexusDeploy modules
# Sizing: small machines, preemptible nodes, single-zone, min replicas = 0
###############################################################################

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "gcs" {} # configured via backend.hcl at init time
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ── Enable Required GCP APIs ────────────────────────────────────────────────
locals {
  required_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr

  depends_on = [google_project_service.apis]
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    gke-nodes = {
      display_name = "GKE Node Service Account"
      description  = "Service account for GKE cluster nodes"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
        "roles/artifactregistry.reader",
      ]
    }
    cloud-run = {
      display_name = "Cloud Run Service Account"
      description  = "Service account for Cloud Run services"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/cloudsql.client",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
      ]
    }
    cloud-functions = {
      display_name = "Cloud Functions Service Account"
      description  = "Service account for Cloud Functions"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/pubsub.publisher",
        "roles/pubsub.subscriber",
        "roles/logging.logWriter",
      ]
    }
  }

  custom_roles = []

  depends_on = [google_project_service.apis]
}

# ── Secret Manager ────────────────────────────────────────────────────────────
module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id = var.project_id

  secrets = {
    db-password   = { value = null }
    api-key       = { value = null }
    slack-webhook = { value = null }
  }

  accessor_sa_emails = [
    module.iam.service_account_emails["gke-nodes"],
    module.iam.service_account_emails["cloud-run"],
  ]

  depends_on = [module.iam, google_project_service.apis]
}

# ── GKE ───────────────────────────────────────────────────────────────────────
module "gke" {
  source = "../../modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = var.cluster_name

  network_id          = module.vpc.network_id
  subnet_id           = module.vpc.subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  node_service_account = module.iam.service_account_emails["gke-nodes"]

  # Dev: preemptible, minimal nodes, scale quickly
  node_count      = var.gke_node_count
  machine_type    = var.gke_machine_type
  min_nodes       = 1
  max_nodes       = 3
  disk_size       = 50
  preemptible     = true
  release_channel = "REGULAR"

  depends_on = [module.vpc, module.iam, google_project_service.apis]
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id    = var.project_id
  region        = var.region
  network_id    = module.vpc.network_id
  instance_name = var.db_instance_name
  database_name = var.db_name
  database_user = "nexusdeploy"
  tier          = var.db_tier

  # Dev: single zone, backups off, no deletion protection
  availability_type   = "ZONAL"
  backup_enabled      = false
  deletion_protection = false

  depends_on = [module.vpc, google_project_service.apis]
}

# ── Cloud Run ─────────────────────────────────────────────────────────────────
module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  region                = var.region
  service_name          = var.cloud_run_service_name
  image                 = var.cloud_run_image
  service_account_email = module.iam.service_account_emails["cloud-run"]

  port          = 8080
  min_instances = 0 # scale to zero in dev
  max_instances = var.cloud_run_max_instances
  cpu           = "1"
  memory        = "512Mi"

  env_vars = {
    ENVIRONMENT = "dev"
    DB_HOST     = module.cloud_sql.private_ip
    DB_NAME     = var.db_name
  }

  deletion_protection   = false
  allow_unauthenticated = false
  invoker_sa_emails     = [module.iam.service_account_emails["cloud-functions"]]

  depends_on = [module.iam, module.cloud_sql, google_project_service.apis]
}

# ── Cloud Functions ───────────────────────────────────────────────────────────
module "event_processor" {
  source = "../../modules/cloud-functions"

  project_id            = var.project_id
  region                = var.region
  function_name         = "nexusdeploy-dev-event-processor"
  runtime               = "python311"
  entry_point           = "main"
  source_bucket         = var.functions_source_bucket
  source_object         = "functions/event-processor.zip"
  service_account_email = module.iam.service_account_emails["cloud-functions"]
  event_trigger_topic   = "nexusdeploy-dev-events"
  create_trigger_topic  = true

  # Dev: minimal resources, retry off
  memory           = "256M"
  timeout_seconds  = 60
  min_instances    = 0
  max_instances    = 2
  retry_on_failure = false

  environment_variables = {
    ENVIRONMENT     = "dev"
    API_SERVICE_URL = module.cloud_run.service_url
  }

  depends_on = [module.iam, module.cloud_run, google_project_service.apis]
}

# ── Monitoring ────────────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  notification_email = var.alert_email
  slack_webhook_url  = var.slack_webhook_url

  uptime_check_hosts = [
    {
      name    = "api-service"
      host    = trimprefix(trimprefix(module.cloud_run.service_url, "https://"), "http://")
      path    = "/health"
      port    = 443
      use_ssl = true
    }
  ]

  # Dev: relaxed thresholds
  alert_thresholds = {
    cpu_percent    = 0.9
    memory_percent = 90
    error_rate_rps = 10
  }

  depends_on = [module.cloud_run, google_project_service.apis]
}

# ── Vertex AI ─────────────────────────────────────────────────────────────────
module "vertex_ai" {
  source = "../../modules/vertex-ai"

  project_id         = var.project_id
  region             = var.vertex_region
  endpoint_name      = "nexusdeploy-dev"
  model_display_name = "NexusDeploy Dev Endpoint"

  # Dev: single replica, smallest machine
  machine_type        = "n1-standard-2"
  min_replica_count   = 1
  max_replica_count   = 1
  create_featurestore = false
}

###############################################################################
# Outputs
###############################################################################

output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "GKE cluster name"
}

output "gke_cluster_endpoint" {
  value       = module.gke.cluster_endpoint
  description = "GKE API server endpoint"
  sensitive   = true
}

output "cloud_run_url" {
  value       = module.cloud_run.service_url
  description = "Cloud Run service URL"
}

output "db_connection_name" {
  value       = module.cloud_sql.connection_name
  description = "Cloud SQL connection name"
}

output "db_private_ip" {
  value       = module.cloud_sql.private_ip
  description = "Cloud SQL private IP"
  sensitive   = true
}

output "vpc_network_id" {
  value       = module.vpc.network_id
  description = "VPC network self-link"
}

output "iam_service_account_emails" {
  value       = module.iam.service_account_emails
  description = "Map of service account names to emails"
}
