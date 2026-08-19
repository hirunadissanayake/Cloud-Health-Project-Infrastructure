output "load_balancer_ip" {
  description = "Global API load-balancer IPv4 address."
  value       = google_compute_global_address.load_balancer.address
}

output "api_url" {
  value = local.https_enabled ? "https://${trimsuffix(var.api_domain, ".")}" : "http://${google_compute_global_address.load_balancer.address}"
}

output "nat_egress_ip" {
  description = "Static Cloud NAT IPv4 address to allow as a /32 entry in MongoDB Atlas."
  value       = google_compute_address.nat.address
}

output "artifact_bucket" {
  value = google_storage_bucket.artifacts.name
}

output "medical_files_bucket" {
  value = google_storage_bucket.medical_files.name
}

output "cloud_sql_private_ip" {
  value = google_sql_database_instance.patient.private_ip_address
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "dns_name_servers" {
  value = local.dns_enabled ? google_dns_managed_zone.application[0].name_servers : []
}

output "workload_identity_provider" {
  description = "Use as google-github-actions/auth workload_identity_provider."
  value       = local.wif_enabled ? google_iam_workload_identity_pool_provider.github[0].name : null
}

output "deployment_service_account" {
  value = local.wif_enabled ? google_service_account.deployment[0].email : null
}
