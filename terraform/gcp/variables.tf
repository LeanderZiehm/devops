
####################
# Free Tier Regions
####################
# QUESTION: what is this a and b? does it matter
locals {
  free_tier_regions = {
    us-east1 = {
      region = "us-east1"
      zone   = "us-east1-b"
      label  = "South Carolina"
    }
    us-central1 = {
      region = "us-central1"
      zone   = "us-central1-a"
      label  = "Iowa"
    }
    us-west1 = {
      region = "us-west1"
      zone   = "us-west1-a"
      label  = "Oregon"
    }
  }

  total_free_disk_gb = 30
  min_disk_per_vm   = 10

  disk_per_instance = floor(local.total_free_disk_gb / var.instance_count)
}

####################
# Variables
####################

# variable "project_id" {
#   type = string
# }

variable "active_region" {
  type    = string
  default = "us-east1"

  validation {
    condition     = contains(keys(local.free_tier_regions), var.active_region)
    error_message = "Region must be one of the Compute Engine Free Tier regions."
  }
}

variable "instance_count" {
  type    = number
  default = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }

  validation {
    condition     = floor(local.total_free_disk_gb / var.instance_count) >= local.min_disk_per_vm
    error_message = "Too many instances: disk per VM ${floor(local.total_free_disk_gb / var.instance_count)} GB would drop below ${local.min_disk_per_vm} GB and exceed Free Tier disk limits."
  }
}
