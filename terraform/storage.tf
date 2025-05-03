# GCS Bucket for Backups
resource "google_storage_bucket" "backup_bucket" {
  name          = var.storage_bucket_name
  location      = var.storage_location
  project       = var.project_id
  force_destroy = true # Allows bucket deletion even if not empty (use with caution)

  uniform_bucket_level_access = true # Recommended for new buckets
}

# Grant public read access (Intentional Misconfiguration)
resource "google_storage_bucket_iam_member" "public_reader" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "public_lister" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.legacyBucketReader" # Allows listing objects
  member = "allUsers"
}

# Grant the DB VM's Service Account permission to write backups to the bucket
resource "google_storage_bucket_iam_member" "db_vm_sa_backup_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin" # Allows creating/overwriting objects
  member = "serviceAccount:${google_service_account.db_vm_sa.email}" # Reference the SA email
}