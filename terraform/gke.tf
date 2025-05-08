resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.zone # Deploy cluster control plane in the specified zone
  project  = var.project_id

  # We can specify the network and subnetwork to use
  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.private.id # Nodes will be in the PRIVATE subnet

  # Remove the default node pool
  remove_default_node_pool = true
  initial_node_count       = 1 # Required even if removing default pool

  # Define logging/monitoring configuration
  logging_service    = "logging.googleapis.com/kubernetes" # Enable Cloud Logging for K8s
  monitoring_service = "monitoring.googleapis.com/kubernetes" # Enable Cloud Monitoring for K8s

  #addons_config {
  #  network_policy_config {
  #    disabled = false # Set to false to enable Network Policy
  #  }
  #}
  
  # Enable GKE Dataplane V2
  datapath_provider = "ADVANCED_DATAPATH"

  # Explicitly enable Network Policy and specify the provider (Calico is common)
  # Network Policy is enabled by default with Dataplane V2.
  #network_policy {
  #  enabled  = true
  #  provider = "CALICO"
  #}

  enable_legacy_abac = false
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  #master_authorized_networks_config {
  #    private_endpoint_enforcement_enabled = true
  #  }

  # --- Private Cluster Configuration ---
  private_cluster_config {
    enable_private_nodes = true # Enable private nodes
    enable_private_endpoint = false # Control plane is accessible externally (adjust if needed)
    # master_ipv4_cidr_block is only needed if enable_private_endpoint = true
    # master_ipv4_cidr_block  = var.gke_master_ipv4_cidr_block
    # Optional: Configure master_global_access_config if enable_private_endpoint=true
  }

  node_config {

    # Use default GKE service account or specify a custom one
    service_account = "github-actions-sa@clgcporg10-183.iam.gserviceaccount.com"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# Separate Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.zone # Can specify zones within the region if needed
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_node_count
  project    = var.project_id

  node_config {
    machine_type = var.gke_node_machine_type
    tags         = [var.gke_nodes_tag, var.network_name] # Apply tag for firewall rules
    # Use default GKE service account or specify a custom one
    service_account = "github-actions-sa@clgcporg10-183.iam.gserviceaccount.com"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  network_config {
    # Nodes in private clusters don't need external IPs
    enable_private_nodes = true
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Output the GKE Pod CIDR range to use in firewall rules
output "gke_pod_ipv4_cidr_block" {
  description = "The IP address range of the Pods in this cluster."
  value       = google_container_cluster.primary.cluster_ipv4_cidr
  # Note: cluster_ipv4_cidr should still be the correct attribute for the Pod range even in private clusters.
}
