output "secret_ids" {
  description = "Map of secret name to secret resource ID"
  value = {
    for k, s in google_secret_manager_secret.secrets : k => s.id
  }
}

output "secret_versions" {
  description = "Map of secret name to secret version resource ID"
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => v.id
  }
}

output "secret_names" {
  description = "Map of secret name to fully qualified secret name"
  value = {
    for k, s in google_secret_manager_secret.secrets : k => s.name
  }
}
