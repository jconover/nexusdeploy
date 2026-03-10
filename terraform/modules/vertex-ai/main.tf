resource "google_project_service" "aiplatform" {
  project = var.project_id
  service = "aiplatform.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "ml" {
  project = var.project_id
  service = "ml.googleapis.com"

  disable_on_destroy = false
}

resource "google_service_account" "vertex_ai" {
  project      = var.project_id
  account_id   = "${var.endpoint_name}-vertex-sa"
  display_name = "Vertex AI Service Account for ${var.endpoint_name}"
  description  = "Service account for Vertex AI workloads"
}

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.vertex_ai.email}"

  depends_on = [google_project_service.aiplatform]
}

resource "google_project_iam_member" "vertex_ai_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vertex_ai.email}"
}

resource "google_project_iam_member" "vertex_ai_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vertex_ai.email}"
}

resource "google_project_iam_member" "vertex_ai_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vertex_ai.email}"
}

resource "google_vertex_ai_endpoint" "main" {
  provider = google-beta

  project      = var.project_id
  name         = var.endpoint_name
  display_name = var.model_display_name
  location     = var.region
  description  = "Vertex AI endpoint for ${var.model_display_name}"

  network = var.network != null ? var.network : null

  depends_on = [
    google_project_service.aiplatform,
    google_project_iam_member.vertex_ai_user,
  ]
}

resource "google_vertex_ai_featurestore" "main" {
  count = var.create_featurestore ? 1 : 0

  provider = google-beta

  project  = var.project_id
  name     = "${var.endpoint_name}-featurestore"
  region   = var.region

  online_serving_config {
    fixed_node_count = var.featurestore_node_count
  }

  depends_on = [google_project_service.aiplatform]
}
