resource "google_storage_bucket" "artifacts" {
  name                        = local.artifact_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                = 30
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required["storage.googleapis.com"]]
}

resource "google_storage_bucket" "medical_files" {
  name                        = local.medical_bucket
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age        = 7
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required["storage.googleapis.com"]]
}

resource "google_storage_bucket_iam_member" "runtime_artifact_reader" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket_iam_member" "runtime_medical_objects" {
  bucket = google_storage_bucket.medical_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = "cloud-health"
  description   = "Cloud Health frontend and deployment containers"
  format        = "DOCKER"

  cleanup_policy_dry_run = true

  depends_on = [google_project_service.required["artifactregistry.googleapis.com"]]
}
