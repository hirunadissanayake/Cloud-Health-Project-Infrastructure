resource "google_compute_health_check" "application" {
  name                = "${local.name_prefix}-health"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port               = 8090
    port_specification = "USE_FIXED_PORT"
    request_path       = "/healthz"
    proxy_header       = "NONE"
  }
}

resource "google_compute_health_check" "autohealing" {
  name                = "${local.name_prefix}-vm-liveness"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 6

  http_health_check {
    port               = 8090
    port_specification = "USE_FIXED_PORT"
    request_path       = "/livez"
    proxy_header       = "NONE"
  }
}

resource "google_compute_instance_template" "application" {
  name_prefix  = "${local.name_prefix}-"
  machine_type = var.machine_type
  tags         = ["cloud-health-backend"]

  disk {
    source_image = var.source_image
    auto_delete  = true
    boot         = true
    disk_type    = "pd-balanced"
    disk_size_gb = var.boot_disk_size_gb
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.application.id

    # Ephemeral external IPv4 address for the assessed VM/Eureka demonstration.
    # Production traffic should continue to enter through the load balancers.
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.runtime.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    project_id              = var.project_id
    release_version         = var.release_version
    java_package            = var.java_package
    artifact_bucket         = google_storage_bucket.artifacts.name
    medical_bucket          = google_storage_bucket.medical_files.name
    database_private_ip     = google_sql_database_instance.patient.private_ip_address
    database_name           = google_sql_database.patient.name
    database_user           = google_sql_user.application.name
    patient_password_secret = google_secret_manager_secret.patient_database_password.secret_id
    mongodb_uri_secret      = google_secret_manager_secret.diagnostics_mongodb_uri.secret_id
    runtime_service_account = google_service_account.runtime.email
    config_git_uri          = var.config_git_uri
    config_git_branch       = var.config_git_branch
    instance_name_prefix    = "${var.environment}-health"
    api_gateway_url         = "http://${google_compute_global_address.load_balancer.address}"
  })

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_project_iam_member.runtime,
    google_storage_bucket_iam_member.runtime_artifact_reader,
    google_storage_bucket_iam_member.runtime_medical_objects,
    google_secret_manager_secret_version.patient_database_password,
    google_secret_manager_secret_version.diagnostics_mongodb_uri
  ]
}

resource "google_compute_region_instance_group_manager" "application" {
  name                      = "${local.name_prefix}-mig"
  base_instance_name        = "${var.environment}-health"
  region                    = var.region
  distribution_policy_zones = var.zones
  target_size               = var.min_replicas

  version {
    name              = "release-${var.release_version}"
    instance_template = google_compute_instance_template.application.self_link_unique
  }

  named_port {
    name = "api"
    port = 8080
  }

  named_port {
    name = "health"
    port = 8090
  }

  named_port {
    name = "platform"
    port = 8870
  }

  named_port {
    name = "webapp"
    port = 3000
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }

  update_policy {
    type                           = "OPPORTUNISTIC"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 2
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

resource "google_compute_region_autoscaler" "application" {
  name   = "${local.name_prefix}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.application.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 180

    cpu_utilization {
      target = var.target_cpu_utilization
    }

    scale_in_control {
      time_window_sec = 300
      max_scaled_in_replicas {
        fixed = 1
      }
    }
  }
}
