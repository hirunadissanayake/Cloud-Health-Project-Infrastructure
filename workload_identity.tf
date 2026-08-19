locals {
  deployment_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudsql.admin",
    "roles/compute.admin",
    "roles/dns.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin"
  ])
}

resource "google_service_account" "deployment" {
  count = local.wif_enabled ? 1 : 0

  account_id   = "${var.environment}-health-deploy"
  display_name = "Cloud Health GitHub deployment"
  description  = "Impersonated by the restricted GitHub OIDC provider; no key files."
}

resource "google_project_iam_member" "deployment" {
  for_each = local.wif_enabled ? local.deployment_roles : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployment[0].email}"
}

resource "google_iam_workload_identity_pool" "github" {
  count = local.wif_enabled ? 1 : 0

  workload_identity_pool_id = "${var.environment}-github"
  display_name              = "Cloud Health GitHub"
  description               = "GitHub Actions identities restricted to ${var.github_repository}."

  depends_on = [google_project_service.required["iam.googleapis.com"]]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = local.wif_enabled ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/main'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com/"
  }
}

resource "google_service_account_iam_member" "github_impersonation" {
  count = local.wif_enabled ? 1 : 0

  service_account_id = google_service_account.deployment[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_repository}"
}
