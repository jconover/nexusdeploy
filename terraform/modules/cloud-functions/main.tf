resource "google_pubsub_topic" "trigger" {
  count = var.create_trigger_topic ? 1 : 0

  project = var.project_id
  name    = var.event_trigger_topic
}

data "google_pubsub_topic" "existing" {
  count = var.create_trigger_topic ? 0 : 1

  project = var.project_id
  name    = var.event_trigger_topic
}

locals {
  trigger_topic_id = var.create_trigger_topic ? google_pubsub_topic.trigger[0].id : data.google_pubsub_topic.existing[0].id
}

resource "google_cloudfunctions2_function" "main" {
  project  = var.project_id
  name     = var.function_name
  location = var.region

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

    source {
      storage_source {
        bucket = var.source_bucket
        object = var.source_object
      }
    }
  }

  service_config {
    service_account_email          = var.service_account_email
    min_instance_count             = var.min_instances
    max_instance_count             = var.max_instances
    available_memory               = var.memory
    timeout_seconds                = var.timeout_seconds
    environment_variables          = length(var.environment_variables) > 0 ? var.environment_variables : null
    vpc_connector                  = var.vpc_connector
    all_traffic_on_latest_revision = true
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = local.trigger_topic_id
    retry_policy          = var.retry_on_failure ? "RETRY_POLICY_RETRY" : "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = var.service_account_email
  }

  depends_on = [google_pubsub_topic.trigger]
}

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.main.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account_email}"
}
