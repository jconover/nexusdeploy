resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  labels = lookup(each.value, "labels", {})

  lifecycle {
    ignore_changes = [labels]
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each = { for k, v in var.secrets : k => v if lookup(v, "value", null) != null }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.value

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each = {
    for item in local.secret_accessor_bindings :
    "${item.secret_id}.${item.email}" => item
  }

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"

  depends_on = [google_secret_manager_secret.secrets]
}

locals {
  secret_accessor_bindings = flatten([
    for secret_id in keys(var.secrets) : [
      for email in var.accessor_sa_emails : {
        secret_id = secret_id
        email     = email
      }
    ]
  ])
}
