#############################################################
# MAIN CONFIGURATION
# - Initializes Terraform & Google provider
# - Loads credentials and project info
# - Automatically loads all .tf files in this directory
#############################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0" # stable for 2025
    }
  }

  # (Optional) Remote backend example — uncomment if you use it
  # backend "gcs" {
  #   bucket = "my-terraform-state-bucket"
  #   prefix = "gcp-infra/state"
  # }
}

# --------------------------
# Provider Configuration
# --------------------------
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  # Optionally specify credentials file if not using Cloud Shell
  # credentials = file("path/to/service-account-key.json")
}

# --------------------------
# Enable Required APIs
# --------------------------
# It's good practice to enable necessary APIs for your resources
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",          # Networking & VMs
    "container.googleapis.com",        # GKE
    "artifactregistry.googleapis.com", # Docker images
    "iam.googleapis.com",              # Service accounts
    "cloudresourcemanager.googleapis.com", # Project IAM
    "servicenetworking.googleapis.com",    # Private services
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])

  service = each.key
  project = var.project_id

  disable_on_destroy = false
}
