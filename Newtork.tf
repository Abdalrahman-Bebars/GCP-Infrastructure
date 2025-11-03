#############################################################
# NETWORK CONFIGURATION
# - Custom VPC
# - Management Subnet (with NAT)
# - Restricted Subnet (private GKE)
# - Firewall rules for subnet isolation
#############################################################

# --------------------------
# Create the Custom VPC
# --------------------------
resource "google_compute_network" "custom_vpc" {
  name                    = "abdalrahman-custom-vpc"
  auto_create_subnetworks = false  # We define custom subnets
  description             = "Custom VPC for management and restricted workloads"
}

# --------------------------
# Management Subnet
# --------------------------
resource "google_compute_subnetwork" "management_subnet" {
  name          = "abdalrahman-management-subnet"
  ip_cidr_range = var.management_subnet_cidr  # e.g., 10.0.1.0/24
  region        = var.region
  network       = google_compute_network.custom_vpc.id
  private_ip_google_access = true  # Needed for private GCP services
  description   = "Subnet for management VM and NAT Gateway"
}

# --------------------------
# Restricted Subnet
# --------------------------
resource "google_compute_subnetwork" "restricted_subnet" {
  name          = "abdalrahman-restricted-subnet"
  ip_cidr_range = var.restricted_subnet_cidr  # e.g., 10.0.2.0/24
  region        = var.region
  network       = google_compute_network.custom_vpc.id
  private_ip_google_access = true  # Needed for private GKE cluster to access GCP services
  description   = "Subnet for private GKE cluster (no internet access)"
  
  # Secondary IP ranges for GKE
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.4.0.0/14"  # Pods CIDR
  }
  
  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.8.0.0/20"  # Services CIDR
  }
}

# --------------------------
# Cloud Router for NAT
# --------------------------
resource "google_compute_router" "management_router" {
  name    = "management-router"
  network = google_compute_network.custom_vpc.id
  region  = var.region
  description = "Router to attach NAT for management subnet"
}

# --------------------------
# NAT Gateway for Management Subnet
# --------------------------
resource "google_compute_router_nat" "management_nat" {
  name                       = "management-nat"
  router                     = google_compute_router.management_router.name  # FIXED: Use name, not id
  region                     = var.region
  nat_ip_allocate_option      = "AUTO_ONLY"  # Let GCP auto-assign external IPs
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                     = google_compute_subnetwork.management_subnet.id
    source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
  }
  subnetwork {
    name                     = google_compute_subnetwork.restricted_subnet.id 
    source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
  }
  min_ports_per_vm = 64
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --------------------------
# Firewall: Allow Management -> Restricted Subnet
# --------------------------
resource "google_compute_firewall" "allow_mgmt_to_restricted" {
  name    = "allow-mgmt-to-restricted"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["443"]  # GKE API
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]   # SSH if needed
  }

  source_ranges = [var.management_subnet_cidr]
  target_tags   = ["restricted-subnet", "gke-node"]
  description   = "Allow management subnet to access GKE control plane and restricted subnet"
}

# --------------------------
# Firewall: Restricted Subnet - Allow GCP Services (EGRESS)
# --------------------------
resource "google_compute_firewall" "allow_restricted_gcp_services" {
  name    = "allow-restricted-gcp-services"
  network = google_compute_network.custom_vpc.id
  priority = 900  # Higher priority than deny rule

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags = ["gke-node"]  # FIXED: Use target_tags for EGRESS
  destination_ranges = [
    "199.36.153.8/30",   # Private Google Access
    "199.36.153.4/30"    # Private Google Access
  ]
  direction = "EGRESS"
  description = "Allow GKE nodes to access GCP APIs"
}

# --------------------------
# Firewall: Allow inter-pod communication (EGRESS)
# --------------------------
resource "google_compute_firewall" "allow_gke_internal" {
  name    = "allow-gke-internal"
  network = google_compute_network.custom_vpc.id
  priority = 900

  allow {
    protocol = "tcp"
  }
  
  allow {
    protocol = "udp"
  }
  
  allow {
    protocol = "icmp"
  }

  target_tags = ["gke-node"]  # FIXED: Use target_tags for EGRESS
  
  destination_ranges = [
    var.restricted_subnet_cidr,
    "10.4.0.0/14",  # Pod CIDR
    "10.8.0.0/20",  # Service CIDR
    "172.16.0.0/28" # Master CIDR
  ]
  
  direction = "EGRESS"
  description = "Allow internal GKE communication between pods, services, and nodes"
}

# --------------------------
# Firewall: Restricted Subnet Isolation (LOWEST PRIORITY)
# --------------------------
resource "google_compute_firewall" "deny_restricted_internet" {
  name    = "deny-restricted-internet"
  network = google_compute_network.custom_vpc.id

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]  # Deny access to internet
  target_tags        = ["gke-node"]  # FIXED: Use target_tags for EGRESS
  direction          = "EGRESS"
  priority           = 65535  # LOWEST priority - only applies if no other rule matches
  description        = "Deny internet access from restricted subnet"
}

# --------------------------
# Firewall: Allow Management NAT Egress
# --------------------------
resource "google_compute_firewall" "allow_mgmt_nat_egress" {
  name    = "allow-mgmt-nat-egress"
  network = google_compute_network.custom_vpc.id

  allow {
    protocol = "all"
  }

  source_ranges = [var.management_subnet_cidr]
  direction     = "EGRESS"
  description   = "Allow outbound traffic from management subnet through NAT"
}

resource "google_compute_firewall" "allow_restricted_to_gar" {
  name      = "allow-restricted-to-gar-nat"
  network   = google_compute_network.custom_vpc.id
  direction = "EGRESS"
  priority  = 700  # Higher priority than deny rule (1000)

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
 # Allow to any destination (traffic goes through NAT)
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["restricted-subnet"]
}
