resource "google_service_account" "accounts" {
  for_each = var.service_accounts

  project      = var.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = lookup(each.value, "description", "")
}

resource "google_project_iam_member" "bindings" {
  for_each = {
    for binding in local.role_bindings : "${binding.sa_key}.${binding.role}" => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.accounts[each.value.sa_key].email}"
}

resource "google_service_account_iam_binding" "workload_identity" {
  for_each = {
    for k, v in var.service_accounts : k => v
    if lookup(v, "workload_identity_namespace", "") != ""
  }

  service_account_id = google_service_account.accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${each.value.workload_identity_namespace}]"
  ]
}

resource "google_project_iam_custom_role" "roles" {
  for_each = { for r in var.custom_roles : r.role_id => r }

  project     = var.project_id
  role_id     = each.value.role_id
  title       = each.value.title
  description = lookup(each.value, "description", "")
  permissions = each.value.permissions

}

resource "google_project_iam_member" "custom_role_bindings" {
  for_each = {
    for binding in local.custom_role_bindings :
    "${binding.sa_key}.${binding.role_id}" => binding
  }

  project = var.project_id
  role    = google_project_iam_custom_role.roles[each.value.role_id].id
  member  = "serviceAccount:${google_service_account.accounts[each.value.sa_key].email}"

  depends_on = [google_project_iam_custom_role.roles]
}

locals {
  role_bindings = flatten([
    for sa_key, sa in var.service_accounts : [
      for role in lookup(sa, "roles", []) : {
        sa_key = sa_key
        role   = role
      }
    ]
  ])

  custom_role_bindings = flatten([
    for sa_key, sa in var.service_accounts : [
      for role_id in lookup(sa, "custom_role_ids", []) : {
        sa_key  = sa_key
        role_id = role_id
      }
    ]
  ])
}
