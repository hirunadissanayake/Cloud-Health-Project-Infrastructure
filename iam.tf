resource "google_service_account" "runtime" {
  account_id   = "${var.environment}-cloud-health-vm"
  display_name = "Cloud Health VM runtime"
  description  = "Least-privilege identity attached to application MIG instances."
}

locals {
  runtime_project_roles = toset([
    "roles/cloudsql.client",
    "roles/datastore.user",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])
}

resource "google_project_iam_member" "runtime" {
  for_each = local.runtime_project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_service_account_iam_member" "runtime_can_sign" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.runtime.email}"
}
