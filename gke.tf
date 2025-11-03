#############################################################
# GKE CONFIGURATION
# - Private GKE Cluster (private control plane)
# - Private Nodes with custom service account
# - Artifact Registry for private images
# - IAM roles for node access to Artifact Registry
#############################################################

# --------------------------
# Custom Service Account for GKE Nodes
# --------------------------
resource "google_service_account" "gke_nodes_sa" {
  account_id   = "gke-nodes-sa"
  display_name = "GKE Nodes Service Account"
  description  = "Custom SA used by GKE nodes instead of the default compute service account"
}

# Grant permissions for node operations and image pulling
resource "google_project_iam_member" "gke_nodes_sa_roles" {
  for_each = toset([
    "roles/container.nodeServiceAccount",   # Basic node permissions
    "roles/artifactregistry.reader",        # Pull private images
    "roles/logging.logWriter",              # Allow node logging
    "roles/monitoring.metricWriter"         # Allow node metrics
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

# --------------------------
# Artifact Registry (Private)
# --------------------------
resource "google_artifact_registry_repository" "gke_repo" {
  provider      = google
  location      = var.region
  repository_id = "gke-private-repo"
  description   = "Private Docker repository for GKE workloads"
  format        = "DOCKER"
}

# --------------------------
# GKE Cluster (Private)
# --------------------------
resource "google_container_cluster" "private_gke" {
  name     = "private-gke-cluster"
  location = var.zone
  project  = var.project_id

  # Network settings
  network    = google_compute_network.custom_vpc.id
  subnetwork = google_compute_subnetwork.restricted_subnet.name

  # Private cluster settings
  private_cluster_config {
    enable_private_nodes    = true     # Nodes have private IPs only
    enable_private_endpoint = true    # CHANGED: Allow public endpoint for Terraform
    master_ipv4_cidr_block  = "172.16.0.0/28"  # GKE control plane range
  }

  # Master authorized networks - only management subnet can access
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.management_subnet_cidr
      display_name = "Management Subnet"
    }
    # Allow your IP for initial setup (optional, remove after setup)
    cidr_blocks {
      cidr_block   = var.admin_public_ip
      display_name = "Admin IP"
    }
  }

  # Service account for nodes
  node_config {
    service_account = google_service_account.gke_nodes_sa.email
    machine_type    = var.gke_node_machine_type  # e.g., e2-medium
    disk_size_gb    = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    tags = ["restricted-subnet", "gke-node"]
  }

  # Enable logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Networking options
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Disable default node pool, create a custom one separately
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
  depends_on = [
    google_compute_subnetwork.restricted_subnet,
    google_project_iam_member.gke_nodes_sa_roles
  ]
}

# --------------------------
# Custom Node Pool
# --------------------------
resource "google_container_node_pool" "private_nodes" {
  name       = "private-node-pool"
  cluster    = google_container_cluster.private_gke.name
  project    = var.project_id
  location   = var.zone

  node_count = var.gke_node_count

  node_config {
    preemptible    = false
    machine_type   = var.gke_node_machine_type
    disk_size_gb   = 50
    service_account = google_service_account.gke_nodes_sa.email
    tags            = ["restricted-subnet", "gke-node"]
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_container_cluster.private_gke
  ]
}

# --------------------------
# Firewall: Allow GKE Master to Nodes
# --------------------------
resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "gke-master-to-nodes"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  source_ranges = ["172.16.0.0/28"]  # GKE master CIDR
  target_tags   = ["gke-node"]
  description   = "Allow GKE master to communicate with nodes"
}

# --------------------------
# Firewall: Allow GKE Health Checks
# --------------------------
resource "google_compute_firewall" "gke_health_check" {
  name    = "gke-health-check"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  target_tags = ["gke-node"]
  description = "Allow GKE load balancer health checks to NodePort range"
}

# --------------------------
# Firewall: Allow webhooks and API server
# --------------------------
resource "google_compute_firewall" "gke_webhooks" {
  name    = "gke-webhooks"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "15017"]
  }

  source_ranges = ["172.16.0.0/28"]  # GKE master CIDR
  target_tags   = ["gke-node"]
  description   = "Allow GKE webhooks from master to nodes"
}