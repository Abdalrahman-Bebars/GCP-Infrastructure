#############################################################
# VARIABLES
# - Central place for all configurable parameters
# - Used by network.tf, gke.tf, vm.tf, and iam.tf
# - Clean, simple, and beginner-friendly
#############################################################

# --------------------------
# Project & Region Settings
# --------------------------
variable "project_id" {
  description = "The GCP project ID where all resources will be created"
  type        = string
}

variable "region" {
  description = "Primary GCP region for resources (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Default zone for resources like VM instances (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

# --------------------------
# Network Configuration
# --------------------------
variable "vpc_name" {
  description = "Name of the custom VPC network"
  type        = string
  default     = "custom-vpc"
}

variable "management_subnet_name" {
  description = "Name of the management subnet"
  type        = string
  default     = "management-subnet"
}

variable "management_subnet_cidr" {
  description = "CIDR block for the management subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "restricted_subnet_name" {
  description = "Name of the restricted subnet for GKE"
  type        = string
  default     = "restricted-subnet"
}

variable "restricted_subnet_cidr" {
  description = "CIDR block for the restricted subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# --------------------------
# GKE Cluster Settings
# --------------------------
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "private-gke-cluster"
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE node pool"
  type        = number
  default     = 2
}

# --------------------------
# VM Settings
# --------------------------
variable "management_vm_name" {
  description = "Name of the private management VM"
  type        = string
  default     = "management-vm"
}

variable "management_vm_machine_type" {
  description = "Machine type for the management VM"
  type        = string
  default     = "e2-medium"
}

# --------------------------
# IAM & Access
# --------------------------
variable "admin_user_email" {
  description = "Admin user email for project-level access (you)"
  type        = string
}

variable "admin_public_ip" {
  description = "Public IP of admin user allowed to SSH into management VM (use /32)"
  type        = string
}

# --------------------------
# Optional Variables (for future flexibility)
# --------------------------
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    "project"     = "gcp-infra"
    "environment" = "dev"
    "owner"       = "abdalrahman"
  }
}
