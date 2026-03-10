output "service_account_emails" {
  description = "Map of service account key to email address"
  value = {
    for k, sa in google_service_account.accounts : k => sa.email
  }
}

output "service_account_ids" {
  description = "Map of service account key to full resource ID"
  value = {
    for k, sa in google_service_account.accounts : k => sa.id
  }
}

output "custom_role_ids" {
  description = "Map of custom role role_id to full IAM role ID"
  value = {
    for k, role in google_project_iam_custom_role.roles : k => role.id
  }
}
