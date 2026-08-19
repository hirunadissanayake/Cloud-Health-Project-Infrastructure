variable "project_id" {
  description = "Existing Google Cloud project with billing enabled."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "environment" {
  description = "Short environment name used in resource names and labels."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.environment))
    error_message = "environment must contain 2-11 lowercase letters, numbers, or hyphens."
  }
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zones" {
  description = "At least two zones in region for the regional managed instance group."
  type        = list(string)
  default     = ["asia-south1-a", "asia-south1-b"]

  validation {
    condition     = length(var.zones) >= 2
    error_message = "Provide at least two zones for regional availability."
  }
}

variable "subnet_cidr" {
  type    = string
  default = "10.20.0.0/20"
}

variable "machine_type" {
  description = "Machine type for full-stack application VMs."
  type        = string
  default     = "e2-standard-4"
}

variable "source_image" {
  description = "Boot image or golden image containing a compatible apt repository."
  type        = string
  default     = "projects/debian-cloud/global/images/family/debian-13"
}

variable "java_package" {
  description = "JRE package installed by the VM startup script. Golden images may set an already-installed package."
  type        = string
  default     = "openjdk-25-jre-headless"
}

variable "boot_disk_size_gb" {
  type    = number
  default = 30
}

variable "min_replicas" {
  type    = number
  default = 2
}

variable "max_replicas" {
  type    = number
  default = 4
}

variable "target_cpu_utilization" {
  type    = number
  default = 0.65
}

variable "release_version" {
  description = "Artifact folder under gs://ARTIFACT_BUCKET/releases/. Change to roll the MIG."
  type        = string
  default     = "v1"
}

variable "config_git_uri" {
  description = "HTTPS Git URI for the Spring Cloud Config repository."
  type        = string
}

variable "config_git_branch" {
  type    = string
  default = "main"
}

variable "artifact_bucket_name" {
  description = "Optional globally unique artifact bucket name."
  type        = string
  default     = ""
}

variable "medical_files_bucket_name" {
  description = "Optional globally unique private medical-files bucket name."
  type        = string
  default     = ""
}

variable "database_tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "database_name" {
  type    = string
  default = "healthcare_patients"
}

variable "database_user" {
  type    = string
  default = "healthcare_app"
}

variable "diagnostics_mongodb_uri" {
  description = "Authenticated MongoDB/Atlas URI stored as a Secret Manager version. Never commit a real value."
  type        = string
  sensitive   = true

  validation {
    condition     = startswith(var.diagnostics_mongodb_uri, "mongodb://") || startswith(var.diagnostics_mongodb_uri, "mongodb+srv://")
    error_message = "diagnostics_mongodb_uri must use mongodb:// or mongodb+srv://."
  }
}

variable "database_deletion_protection" {
  description = "Protect Cloud SQL at both Terraform and Google API layers."
  type        = bool
  default     = true
}

variable "firestore_location" {
  type    = string
  default = "asia-south1"
}

variable "api_domain" {
  description = "Optional FQDN for HTTPS and the API A record, for example api.example.com."
  type        = string
  default     = ""
}

variable "create_dns_zone" {
  description = "Create a public Cloud DNS zone. Set false when DNS is managed elsewhere."
  type        = bool
  default     = false
}

variable "dns_zone_dns_name" {
  description = "Root DNS name with or without trailing dot, for example example.com."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Optional owner/repository allowed to use GitHub OIDC, for example owner/cloud-health-infra."
  type        = string
  default     = ""
}

variable "labels" {
  type        = map(string)
  description = "Additional labels applied through the provider."
  default     = {}
}
