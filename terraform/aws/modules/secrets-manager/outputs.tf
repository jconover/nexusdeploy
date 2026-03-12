output "secret_arns" {
  description = "Map of secret key to ARN"
  sensitive   = false
  value = {
    for k, s in aws_secretsmanager_secret.secrets : k => s.arn
  }
}

output "secret_names" {
  description = "Map of secret key to name"
  value = {
    for k, s in aws_secretsmanager_secret.secrets : k => s.name
  }
}

output "secret_version_ids" {
  description = "Map of secret key to version ID (only for secrets with initial values set)"
  value = {
    for k, v in aws_secretsmanager_secret_version.versions : k => v.version_id
  }
}
