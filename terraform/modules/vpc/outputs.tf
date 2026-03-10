output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "The ID of the primary subnet"
  value       = google_compute_subnetwork.main.id
}

output "subnet_name" {
  description = "The name of the primary subnet"
  value       = google_compute_subnetwork.main.name
}

output "pods_range_name" {
  description = "The secondary range name for GKE pods"
  value       = "${var.network_name}-pods"
}

output "services_range_name" {
  description = "The secondary range name for GKE services"
  value       = "${var.network_name}-services"
}
