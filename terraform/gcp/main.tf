# Question how do I define required version?
# TODO:  and update google version
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      version = "7.17.0"
    }
  }
}
####################
# Provider
####################

provider "google" {
  # project = var.project_id
  # region  = local.free_tier_regions[var.active_region].region
  # zone    = local.free_tier_regions[var.active_region].zone
}


# Enable the IAM API
resource "google_project_service" "iam" {
  # project = "908254196485"
  service = "iam.googleapis.com"
  # optional: prevent Terraform from deleting the service if you destroy resources
  disable_on_destroy = false
}

resource "google_service_account" "my-sa-resource-name" {
  account_id = "my-sa-resource-name-id"
  display_name = "Custom Service Account for VM Instance :)"
    depends_on = [google_project_service.iam]
  
}


####################
# Compute Instances
####################
# TODO: Update to debian 13 
# Question is debian-cloud best? what is pd-standard?
resource "google_compute_instance" "e2_micro" {
  count        = var.instance_count
  name         = "free-tier-${var.active_region}-${count.index}"
  machine_type = "e2-micro"
  zone         = local.free_tier_regions[var.active_region].zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = local.disk_per_instance
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  metadata = {
    ssh-keys = "what-name-is-this-for:${file("~/.ssh/gcp.pub")} ssh"
  }

  tags = ["ssh"]
 
  service_account {
    email = google_service_account.my-sa-resource-name.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "ssh-firewall-access" {
  name = "ssh-access"
  network = "default"
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = [ "ssh" ]
  source_ranges = ["0.0.0.0/0"]
  
}