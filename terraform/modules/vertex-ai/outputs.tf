output "endpoint_id" {
  description = "The ID of the Vertex AI endpoint"
  value       = google_vertex_ai_endpoint.main.id
}

output "endpoint_name" {
  description = "The name of the Vertex AI endpoint"
  value       = google_vertex_ai_endpoint.main.name
}

output "endpoint_resource_name" {
  description = "The full resource name of the endpoint"
  value       = google_vertex_ai_endpoint.main.name
}

output "service_account_email" {
  description = "The service account email for Vertex AI workloads"
  value       = google_service_account.vertex_ai.email
}

output "featurestore_id" {
  description = "The Vertex AI Feature Store ID (null if not created)"
  value       = var.create_featurestore ? google_vertex_ai_featurestore.main[0].id : null
}
