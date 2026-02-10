output "disk_allocation" {
  value = {
    total_disk_gb     = local.total_free_disk_gb
    instance_count    = var.instance_count
    disk_per_instance = local.disk_per_instance
  }
}

output "instance_ips" {
  value = google_compute_instance.e2_micro[*].network_interface[0].access_config[0].nat_ip
}
