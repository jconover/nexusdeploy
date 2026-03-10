output "function_uri" {
  description = "The URI of the Cloud Function"
  value       = google_cloudfunctions2_function.main.service_config[0].uri
}

output "function_name" {
  description = "The name of the Cloud Function"
  value       = google_cloudfunctions2_function.main.name
}

output "function_id" {
  description = "The full resource ID of the Cloud Function"
  value       = google_cloudfunctions2_function.main.id
}

output "trigger_topic_id" {
  description = "The Pub/Sub topic ID used as event trigger"
  value       = local.trigger_topic_id
}
