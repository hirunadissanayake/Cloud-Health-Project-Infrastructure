resource "google_compute_global_address" "load_balancer" {
  name         = "${local.name_prefix}-api-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_backend_service" "application" {
  name                            = "${local.name_prefix}-backend"
  protocol                        = "HTTP"
  port_name                       = "api"
  timeout_sec                     = 30
  connection_draining_timeout_sec = 30
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  health_checks                   = [google_compute_health_check.application.id]

  backend {
    group           = google_compute_region_instance_group_manager.application.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "application" {
  name            = "${local.name_prefix}-api-map"
  default_service = google_compute_backend_service.application.id
}

resource "google_compute_url_map" "https_redirect" {
  count = local.https_enabled ? 1 : 0

  name = "${local.name_prefix}-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "application" {
  name    = "${local.name_prefix}-http-proxy"
  url_map = local.https_enabled ? google_compute_url_map.https_redirect[0].id : google_compute_url_map.application.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.name_prefix}-http"
  target                = google_compute_target_http_proxy.application.id
  ip_address            = google_compute_global_address.load_balancer.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

resource "google_compute_managed_ssl_certificate" "application" {
  count = local.https_enabled ? 1 : 0

  name = "${local.name_prefix}-certificate"

  managed {
    domains = [trimsuffix(var.api_domain, ".")]
  }
}

resource "google_compute_ssl_policy" "application" {
  count = local.https_enabled ? 1 : 0

  name            = "${local.name_prefix}-tls-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "application" {
  count = local.https_enabled ? 1 : 0

  name             = "${local.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.application.id
  ssl_certificates = [google_compute_managed_ssl_certificate.application[0].id]
  ssl_policy       = google_compute_ssl_policy.application[0].id
}

resource "google_compute_global_forwarding_rule" "https" {
  count = local.https_enabled ? 1 : 0

  name                  = "${local.name_prefix}-https"
  target                = google_compute_target_https_proxy.application[0].id
  ip_address            = google_compute_global_address.load_balancer.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}
