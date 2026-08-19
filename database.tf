resource "random_password" "patient_database" {
  length           = 32
  special          = true
  override_special = "_-!#"
}

resource "google_sql_database_instance" "patient" {
  name                = "${local.name_prefix}-postgres"
  region              = var.region
  database_version    = "POSTGRES_17"
  deletion_protection = var.database_deletion_protection

  settings {
    tier              = var.database_tier
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 20
    disk_autoresize   = true

    deletion_protection_enabled = var.database_deletion_protection

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "18:00"
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7
      hour         = 19
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }

  depends_on = [
    google_project_service.required["sqladmin.googleapis.com"],
    google_service_networking_connection.private_services
  ]
}

resource "google_sql_database" "patient" {
  name     = var.database_name
  instance = google_sql_database_instance.patient.name
}

resource "google_sql_user" "application" {
  name     = var.database_user
  instance = google_sql_database_instance.patient.name
  password = random_password.patient_database.result
}

resource "google_firestore_database" "medical_metadata" {
  project                           = var.project_id
  name                              = "(default)"
  location_id                       = var.firestore_location
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  deletion_policy                   = "ABANDON"

  depends_on = [google_project_service.required["firestore.googleapis.com"]]
}
