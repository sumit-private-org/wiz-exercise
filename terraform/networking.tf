# VPC Network
resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false # Recommended to manage subnets explicitly
  mtu                     = 1460
}

# Public Subnet
resource "google_compute_subnetwork" "public" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

# Private Subnet (for GKE)
resource "google_compute_subnetwork" "private" {
  name                     = var.private_subnet_name
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true # Allows VMs without external IPs to reach Google APIs
}

# --- Firewall Rules ---

# Allow SSH from anywhere (Intentional Misconfiguration)
resource "google_compute_firewall" "allow_ssh_external" {
  name    = "${var.network_name}-allow-ssh-external"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.db_server_tag] # Apply only to the DB VM
  description   = "Allow SSH access from the public internet to DB VM (Insecure)"
}

# Allow MongoDB access ONLY from GKE Pods
resource "google_compute_firewall" "allow_mongo_from_gke" {
  name    = "${var.network_name}-allow-mongo-from-gke"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["27017"] # Default MongoDB port
  }

  # IMPORTANT: Use the placeholder variable for now.
  # For a production setup, you'd replace this with the actual GKE Pod CIDR
  # obtained from the google_container_cluster resource output.
  # e.g., source_ranges = [google_container_cluster.primary.pod_ipv4_cidr_block]
  # Use the actual Pod CIDR output from the GKE cluster resource
  # Use cluster_ipv4_cidr for standard public clusters
  source_ranges = [google_container_cluster.primary.cluster_ipv4_cidr]

  target_tags = [var.db_server_tag] # Apply only to the DB VM
  description = "Allow MongoDB access only from GKE Pods"
}

# Allow all Egress traffic (Often default, but explicit here)
resource "google_compute_firewall" "allow_egress_all" {
  name    = "${var.network_name}-allow-egress-all"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  direction          = "EGRESS"
  priority           = 1000 # Default priority
  description        = "Allow all outbound traffic from the VPC"
}

# Allow GCP Health Checks (Needed for GKE LoadBalancers/Ingress)
resource "google_compute_firewall" "allow_gcp_health_checks" {
  name    = "${var.network_name}-allow-gcp-health-checks"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    # Add ports your application/ingress might use for health checks
    ports = ["80", "443", "8080", "8888", "10256"] # Common ports + Kubelet health check port
  }

  # GCP Health Checker IP Ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  # Apply to nodes that will serve traffic (e.g., GKE nodes)
  # You'll apply the 'gke-node' tag to your GKE node pools later.
  target_tags = [var.gke_nodes_tag]
  description = "Allow GCP Health Checkers for Load Balancing"
}

# Allow HTTP/HTTPS from anywhere for GKE Load Balancer/Ingress
resource "google_compute_firewall" "allow_http_https_external" {
  name    = "${var.network_name}-allow-http-https-external"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]

  # Apply to nodes that will serve traffic (e.g., GKE nodes)
  target_tags = [var.gke_nodes_tag]
  description = "Allow external HTTP/HTTPS traffic to GKE nodes for Load Balancer/Ingress"
}

# --- Cloud NAT for Private Subnet Egress ---

# Cloud Router
resource "google_compute_router" "router" {
  name    = var.cloud_router_name
  region  = google_compute_subnetwork.private.region
  network = google_compute_network.main.id
  project = var.project_id
}

# Cloud NAT Configuration
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat-gateway"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  project                            = var.project_id
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  nat_ip_allocate_option             = "AUTO_ONLY"
  # Optional: Increase minimum ports per VM if needed for high connection rates
  # min_ports_per_vm = 4096
}
