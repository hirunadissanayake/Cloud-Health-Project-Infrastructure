packer {
  required_plugins {
    googlecompute = {
      version = "~> 1.2"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "asia-south1-a"
}

variable "java_package" {
  type    = string
  default = "openjdk-25-jre-headless"
}

source "googlecompute" "cloud_health" {
  project_id              = var.project_id
  zone                    = var.zone
  source_image_family     = "debian-13"
  source_image_project_id = ["debian-cloud"]
  ssh_username            = "packer"
  image_name              = "cloud-health-java25-${formatdate("YYYYMMDDhhmm", timestamp())}"
  image_family            = "cloud-health-java25"
  image_description       = "Java 25, Node.js, PM2, and Ops Agent base for Cloud Health"
  image_labels = {
    application = "cloud-health"
    managed-by  = "packer"
  }
}

build {
  sources = ["source.googlecompute.cloud_health"]

  provisioner "shell" {
    script           = "${path.root}/provision-image.sh"
    environment_vars = ["JAVA_PACKAGE=${var.java_package}"]
  }
}
