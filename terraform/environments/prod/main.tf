###############################################################################
# Production environment – regional HA, no preemptible, 3+ nodes,
# point-in-time recovery, Binary Authorization, strict alert thresholds.
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

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
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
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    gke-nodes = {
      display_name = "GKE Node Service Account (prod)"
      description  = "Service account for GKE cluster nodes"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
        "roles/artifactregistry.reader",
      ]
    }
    cloud-run = {
      display_name = "Cloud Run Service Account (prod)"
      description  = "Service account for Cloud Run services"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/cloudsql.client",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
      ]
    }
    cloud-functions = {
      display_name = "Cloud Functions Service Account (prod)"
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

  depends_on = [module.iam]
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

  # Prod: regional, no preemptible, larger machines, maintenance window set
  node_count      = var.gke_node_count
  machine_type    = var.gke_machine_type
  min_nodes       = 3
  max_nodes       = 10
  disk_size       = 200
  preemptible     = false
  release_channel = "STABLE"

  depends_on = [module.vpc, module.iam]
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

  # Prod: regional HA (automatic failover), backups on, deletion protection
  availability_type   = "REGIONAL"
  backup_enabled      = true
  deletion_protection = true

  depends_on = [module.vpc]
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
  min_instances = var.cloud_run_min_instances   # always-warm in prod
  max_instances = var.cloud_run_max_instances
  cpu           = "2"
  memory        = "2Gi"

  env_vars = {
    ENVIRONMENT = "prod"
    DB_HOST     = module.cloud_sql.private_ip
    DB_NAME     = var.db_name
  }

  allow_unauthenticated = false
  invoker_sa_emails     = [module.iam.service_account_emails["cloud-functions"]]

  depends_on = [module.iam, module.cloud_sql]
}

# ── Cloud Functions ───────────────────────────────────────────────────────────
module "event_processor" {
  source = "../../modules/cloud-functions"

  project_id            = var.project_id
  region                = var.region
  function_name         = "nexusdeploy-prod-event-processor"
  runtime               = "python311"
  entry_point           = "main"
  source_bucket         = var.functions_source_bucket
  source_object         = "functions/event-processor.zip"
  service_account_email = module.iam.service_account_emails["cloud-functions"]
  event_trigger_topic   = "nexusdeploy-prod-events"
  create_trigger_topic  = true

  # Prod: higher memory, always-warm, retry enabled
  memory           = "1G"
  timeout_seconds  = 300
  min_instances    = 2
  max_instances    = 20
  retry_on_failure = true

  environment_variables = {
    ENVIRONMENT     = "prod"
    API_SERVICE_URL = module.cloud_run.service_url
  }

  depends_on = [module.iam, module.cloud_run]
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

  # Prod: tight thresholds, page on critical
  alert_thresholds = {
    cpu_percent    = 0.7
    memory_percent = 70
    error_rate_rps = 1
  }

  depends_on = [module.cloud_run]
}

# ── Vertex AI ─────────────────────────────────────────────────────────────────
module "vertex_ai" {
  source = "../../modules/vertex-ai"

  project_id         = var.project_id
  region             = var.vertex_region
  endpoint_name      = "nexusdeploy-prod"
  model_display_name = "NexusDeploy Production Endpoint"

  # Prod: multiple replicas, dedicated hardware
  machine_type        = "n1-standard-8"
  min_replica_count   = 2
  max_replica_count   = 5
  create_featurestore = true
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
