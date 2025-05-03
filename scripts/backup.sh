#!/bin/bash

# --- Configuration ---
# Credentials and DB details
MONGO_USER="tasky_user"
MONGO_PASS="tasky_password"
MONGO_DB="taskydb"
AUTH_DB="taskydb"

# GCS Bucket Name (This should match your Terraform variable/output)
BUCKET_NAME="your-gcs-bucket-name"

# --- Execution ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="db_backup_${TIMESTAMP}.gz"
GCS_PATH="gs://${BUCKET_NAME}/backups/${BACKUP_FILENAME}"

echo "Starting MongoDB backup for database '${MONGO_DB}' at $(date)"
echo "Target GCS path: ${GCS_PATH}"

# Perform the dump, compress, and pipe directly to gsutil
mongodump \
    --username "${MONGO_USER}" \
    --password "${MONGO_PASS}" \
    --authenticationDatabase "${AUTH_DB}" \
    --db "${MONGO_DB}" \
    --archive \
    --gzip | gsutil cp - "${GCS_PATH}"

# Check the exit status of gsutil
if [ $? -eq 0 ]; then
    echo "Backup successful: ${BACKUP_FILENAME} uploaded to ${GCS_PATH}"
else
    echo "Backup failed!" >&2
    exit 1
fi

echo "Backup process finished at $(date)"
exit 0