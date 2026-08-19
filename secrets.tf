resource "google_secret_manager_secret" "patient_database_password" {
  secret_id = "${local.name_prefix}-patient-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "patient_database_password" {
  secret      = google_secret_manager_secret.patient_database_password.id
  secret_data = random_password.patient_database.result
}

resource "google_secret_manager_secret" "diagnostics_mongodb_uri" {
  secret_id = "${local.name_prefix}-mongodb-uri"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required["secretmanager.googleapis.com"]]
}

resource "google_secret_manager_secret_version" "diagnostics_mongodb_uri" {
  secret      = google_secret_manager_secret.diagnostics_mongodb_uri.id
  secret_data = var.diagnostics_mongodb_uri
}

resource "google_secret_manager_secret_iam_member" "runtime_patient_password" {
  secret_id = google_secret_manager_secret.patient_database_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "runtime_mongodb_uri" {
  secret_id = google_secret_manager_secret.diagnostics_mongodb_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}
