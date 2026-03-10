output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "cluster_id" {
  description = "The full resource ID of the GKE cluster"
  value       = google_container_cluster.main.id
}

output "workload_identity_pool" {
  description = "The workload identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}
