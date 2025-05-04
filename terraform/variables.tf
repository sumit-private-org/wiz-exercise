
variable "project_id" {
  description = "The GCP project ID."
  type        = string
  default     = "clgcporg10-183"
}

variable "region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "us-central1" # Or your preferred region
}

variable "zone" {
  description = "The Zone within the GCP region to deploy Zonal GKE control plane."
  type        = string
  default     = "us-central1-a" # Or your preferred zone
}

variable "network_name" {
  description = "The name for the VPC network."
  type        = string
  default     = "wiz-vpc"
}

variable "subnet_name" {
  description = "The name for the public subnet."
  type        = string
  default     = "public-subnet"
}

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
  default     = "10.10.10.0/24"
}

variable "private_subnet_name" {
  description = "The name for the private subnet (for GKE)."
  type        = string
  default     = "private-subnet"
}

variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet."
  type        = string
  default     = "10.10.20.0/24" # Ensure this doesn't overlap with public subnet
}

#variable "gke_master_ipv4_cidr_block" {
#  description = "The CIDR block for the GKE control plane (required for private cluster)."
#  type        = string
#  default     = "172.16.0.0/28" # Must be /28, RFC1918, and unique within the VPC
#}

variable "db_server_tag" {
  description = "Network tag for the database server VM."
  type        = string
  default     = "db-server"
}

variable "gke_nodes_tag" {
  description = "Network tag for GKE nodes (for health checks)."
  type        = string
  default     = "gke-node" # You might apply this tag to your node pools later
}

# Note: gke_pod_cidr is determined by GKE itself, we reference the output.
# variable "gke_pod_cidr" { ... } # Removed as we use the cluster output directly

variable "cloud_router_name" {
  description = "Name for the Cloud Router."
  type        = string
  default     = "wiz-router"
}
variable "db_vm_name" {
  description = "Name for the database VM instance."
  type        = string
  default     = "mongodb-vm"
}

variable "db_vm_zone" {
  description = "GCP zone for the database VM instance."
  type        = string
  default     = "us-central1-a" # Choose a zone within your region
}

variable "db_vm_image" {
  description = "Outdated Linux image for the DB VM (e.g., Ubuntu 20.04)."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "db_vm_machine_type" {
  description = "Machine type for the DB VM."
  type        = string
  default     = "e2-medium"
}

variable "db_vm_service_account_name" {
  description = "Name for the DB VM's overly permissive service account."
  type        = string
  default     = "db-vm-overly-permissive-sa"
}

variable "storage_bucket_name" {
  description = "Name for the public GCS bucket. Needs to be globally unique."
  type        = string
  # Note: Bucket names must be globally unique.
  # Set this value in your terraform.tfvars file.
}

variable "storage_location" {
  description = "Location for the GCS bucket."
  type        = string
  default     = "US" # Or your preferred multi-region/region
}

variable "gke_cluster_name" {
  description = "Name for the GKE cluster."
  type        = string
  default     = "wiz-cluster"
}

variable "gke_node_count" {
  description = "Number of nodes per zone in the GKE node pool."
  type        = number
  default     = 1
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes."
  type        = string
  default     = "e2-medium"
}

variable "artifact_registry_repository_name" {
  description = "Name for the Artifact Registry Docker repository."
  type        = string
  default     = "wiz-app-repo"
}
