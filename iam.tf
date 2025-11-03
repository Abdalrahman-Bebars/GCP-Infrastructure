#############################################################
# IAM CONFIGURATION
# - Central IAM definitions for project-wide access
# - Creates and binds custom service accounts
# - Follows least-privilege principle
#############################################################

# --------------------------
# Custom Service Accounts
# --------------------------

# Management VM Service Account
resource "google_service_account" "management_vm_sa" {
  account_id   = "management-vm-sa"
  display_name = "Management VM Service Account"
  description  = "Used by the management VM to access GKE and Artifact Registry"
}



# --------------------------
# IAM Role Bindings for Management VM
# --------------------------
resource "google_project_iam_member" "management_vm_roles" {
  for_each = toset([
    "roles/container.admin",         # Manage GKE via kubectl
    "roles/artifactregistry.reader", # Pull Docker images
    "roles/viewer"                   # View other resources
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.management_vm_sa.email}"
}

# --------------------------
# (Optional) Admin User IAM Access
# --------------------------
# Gives you permissions to manage the GKE cluster & VM
resource "google_project_iam_member" "admin_user_roles" {
  for_each = toset([
    "roles/container.admin",          # GKE management
    "roles/compute.admin",            # Manage networks, instances
    "roles/artifactregistry.admin"    # Manage private repos
  ])
  project = var.project_id
  role    = each.key
  member  = "user:${var.admin_user_email}"
}

# --------------------------
# Outputs
# --------------------------

output "management_vm_sa_email" {
  value       = google_service_account.management_vm_sa.email
  description = "Email of the management VM service account"
}
