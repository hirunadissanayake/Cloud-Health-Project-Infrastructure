locals {
  name_prefix = "${var.environment}-cloud-health"
  labels = merge({
    application = "cloud-health"
    environment = var.environment
    managed-by  = "terraform"
  }, var.labels)

  artifact_bucket = var.artifact_bucket_name != "" ? var.artifact_bucket_name : "${var.project_id}-cloud-health-artifacts"
  medical_bucket  = var.medical_files_bucket_name != "" ? var.medical_files_bucket_name : "${var.project_id}-medical-files"
  https_enabled   = var.api_domain != ""
  dns_enabled     = var.create_dns_zone && var.dns_zone_dns_name != "" && var.api_domain != ""
  wif_enabled     = var.github_repository != ""

  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com"
  ])
}
