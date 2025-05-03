# /path/to/your/project/terraform/providers.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.33.0" # Use a recent version
    }
  }

  # Optional: Configure GCS backend for state management
  # backend "gcs" {
  #   bucket = var.storage_bucket_name # Replace with your GCS bucket name
  #   prefix = "terraform-state/"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

