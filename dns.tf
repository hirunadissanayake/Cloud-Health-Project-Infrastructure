resource "google_dns_managed_zone" "application" {
  count = local.dns_enabled ? 1 : 0

  name        = "${local.name_prefix}-zone"
  dns_name    = "${trimsuffix(var.dns_zone_dns_name, ".")}."
  description = "Public DNS zone for the Cloud Health course project"

  dnssec_config {
    state = "on"
  }

  depends_on = [google_project_service.required["dns.googleapis.com"]]
}

resource "google_dns_record_set" "api" {
  count = local.dns_enabled ? 1 : 0

  name         = "${trimsuffix(var.api_domain, ".")}."
  managed_zone = google_dns_managed_zone.application[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.load_balancer.address]
}
