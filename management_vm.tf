# --------------------------
# Management VM Configuration
# --------------------------
resource "google_compute_instance" "management_vm" {
  name         = var.management_vm_name
  machine_type = var.management_vm_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.management_subnet.id
    # No external IP - private VM
  }

  service_account {
    email  = google_service_account.management_vm_sa.email
    scopes = ["cloud-platform"]
  }

  # Install necessary tools
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y kubectl google-cloud-sdk-gke-gcloud-auth-plugin
    EOF

  tags = ["management-vm"]

  depends_on = [
    google_compute_subnetwork.management_subnet
  ]
}

# Firewall rule to allow IAP for SSH access to management VM
resource "google_compute_firewall" "iap_to_management_vm" {
  name    = "allow-iap-to-management"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]  # SSH
  }

  source_ranges = ["35.235.240.0/20"]  # IAP range
  target_tags   = ["management-vm"]
  description   = "Allow SSH from IAP to management VM"
}