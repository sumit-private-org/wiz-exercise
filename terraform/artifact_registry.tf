resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.artifact_registry_repository_name
  description   = "Docker repository for Wiz exercise web application"
  format        = "DOCKER"
  project       = var.project_id
}

