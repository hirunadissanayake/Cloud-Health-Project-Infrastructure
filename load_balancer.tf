resource "google_compute_global_address" "load_balancer" {
  name         = "${local.name_prefix}-api-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_backend_service" "application" {
  name                            = "backend-api-gateway"
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
  name            = "lb-api-gateway-map"
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
  name    = "lb-api-gateway-proxy"
  url_map = local.https_enabled ? google_compute_url_map.https_redirect[0].id : google_compute_url_map.application.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "lb-api-gateway"
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

resource "google_compute_global_address" "webapp" {
  name         = "lb-webapp-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_health_check" "webapp" {
  name                = "health-webapp"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = 3000
    port_specification = "USE_FIXED_PORT"
    request_path       = "/healthz"
    proxy_header       = "NONE"
  }
}

resource "google_compute_backend_service" "webapp" {
  name                            = "backend-webapp"
  protocol                        = "HTTP"
  port_name                       = "webapp"
  timeout_sec                     = 30
  connection_draining_timeout_sec = 30
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  health_checks                   = [google_compute_health_check.webapp.id]

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

resource "google_compute_url_map" "webapp" {
  name            = "lb-webapp-map"
  default_service = google_compute_backend_service.webapp.id
}

resource "google_compute_target_http_proxy" "webapp" {
  name    = "lb-webapp-proxy"
  url_map = google_compute_url_map.webapp.id
}

resource "google_compute_global_forwarding_rule" "webapp" {
  name                  = "lb-webapp"
  target                = google_compute_target_http_proxy.webapp.id
  ip_address            = google_compute_global_address.webapp.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

resource "google_compute_global_address" "platform" {
  name         = "lb-platform-configserver-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_health_check" "platform" {
  name                = "health-platform-configserver"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = 8870
    port_specification = "USE_FIXED_PORT"
    request_path       = "/healthz"
    proxy_header       = "NONE"
  }
}

resource "google_compute_backend_service" "platform" {
  name                  = "backend-platform-configserver"
  protocol              = "HTTP"
  port_name             = "platform"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.platform.id]

  backend {
    group           = google_compute_region_instance_group_manager.application.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "platform" {
  name            = "lb-platform-configserver-map"
  default_service = google_compute_backend_service.platform.id
}

resource "google_compute_target_http_proxy" "platform" {
  name    = "lb-platform-configserver-proxy"
  url_map = google_compute_url_map.platform.id
}

resource "google_compute_global_forwarding_rule" "platform_config" {
  name                  = "lb-platform-configserver"
  target                = google_compute_target_http_proxy.platform.id
  ip_address            = google_compute_global_address.platform.id
  port_range            = "8888"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

resource "google_compute_global_forwarding_rule" "platform_eureka" {
  name                  = "lb-platform-configserver-eureka"
  target                = google_compute_target_http_proxy.platform.id
  ip_address            = google_compute_global_address.platform.id
  port_range            = "8761"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}
