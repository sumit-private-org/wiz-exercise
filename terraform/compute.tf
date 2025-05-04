# Service Account for the DB VM
resource "google_service_account" "db_vm_sa" {
  account_id   = var.db_vm_service_account_name
  display_name = "Overly Permissive SA for DB VM"
  project      = var.project_id
}

# Grant overly permissive role (Editor) at the project level (Intentional Misconfiguration)
resource "google_project_iam_member" "db_vm_sa_editor_binding" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.db_vm_sa.email}"
}

# Database VM Instance
resource "google_compute_instance" "db_vm" {
  name         = var.db_vm_name
  machine_type = var.db_vm_machine_type
  zone         = var.db_vm_zone
  project      = var.project_id

  tags = [var.db_server_tag] # Apply tag for firewall rules

  boot_disk {
    initialize_params {
      image = var.db_vm_image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id # Attach to the public subnet

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    email  = google_service_account.db_vm_sa.email
    scopes = ["cloud-platform"] # Allows access based on IAM roles
  }

  # Startup script to install outdated MongoDB, configure auth, setup backup script & cron
  metadata_startup_script = <<-STARTUP
    #!/bin/bash
    echo "Starting VM setup..."
    # --- Install Outdated MongoDB (Example - Ubuntu 20.04) ---
    # Use a specific older version, e.g., 4.4. 
    MONGO_VERSION="4.4.29" # Specify desired outdated version
    echo "Installing MongoDB $${MONGO_VERSION}..."
    sudo apt-get update
    sudo apt-get install -y gnupg curl cron
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org=$${MONGO_VERSION} mongodb-org-server=$${MONGO_VERSION} mongodb-org-shell=$${MONGO_VERSION} mongodb-org-mongos=$${MONGO_VERSION} mongodb-org-tools=$${MONGO_VERSION}
    sudo systemctl start mongod
    sudo systemctl enable mongod

    # --- Configure MongoDB for Authentication & Network Binding ---
    echo "Configuring MongoDB authentication..."
    # Wait a bit for mongod to be ready
    sleep 15
    mongo --eval 'db.getSiblingDB("admin").createUser({user: "mongo_admin", pwd: "admin_password", roles: [{role: "userAdminAnyDatabase", db: "admin"}]})'
    mongo --eval 'db.getSiblingDB("taskydb").createUser({user: "tasky_user", pwd: "tasky_password", roles: [{role: "readWrite", db: "taskydb"}]})' -u mongo_admin -p admin_password --authenticationDatabase admin

    # Update mongod.conf to bind to all IPs (or internal IP) and enable auth
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    echo -e "\nsecurity:\n  authorization: enabled" | sudo tee -a /etc/mongod.conf > /dev/null
    sudo systemctl restart mongod
    echo "MongoDB configuration updated."

    # --- Setup Backup Script and Cron Job ---
    echo "Setting up backup script and cron job..."
    mkdir -p /scripts
    # Use the actual bucket name from the Terraform resource
    
    cat <<-BACKUP > /scripts/backup.sh
    #!/bin/bash

    # --- Configuration ---
    MONGO_USER="tasky_user"
    MONGO_PASS="tasky_password" # Use the actual password
    MONGO_DB="taskydb"
    AUTH_DB="taskydb"
    BUCKET_NAME="${google_storage_bucket.backup_bucket.name}" # Injected by Terraform
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILENAME="mongodb_backup_\$${TIMESTAMP}.gz" # Escaped $ for literal timestamp variable in script
    GCS_PATH="gs://\$${BUCKET_NAME}/backups/\$${BACKUP_FILENAME}" # bucket path

    # --- Execution ---

    echo "Starting MongoDB backup for database '\$${MONGO_DB}' at \$$(date)" # Escaped $
    echo "Target GCS path: \$${GCS_PATH}" # Escaped $

    mongodump \\
        --username "\$${MONGO_USER}" \\
        --password "\$${MONGO_PASS}" \\
        --authenticationDatabase "\$${AUTH_DB}" \\
        --db "\$${MONGO_DB}" \\
        --archive \\
        --gzip | gsutil cp - "\$${GCS_PATH}"

    if [ \$? -eq 0 ]; then # Escaped $
        echo "Backup successful: \$${BACKUP_FILENAME} uploaded to \$${GCS_PATH}" # Escaped $
    else
        echo "Backup failed!" >&2
        exit 1
    fi

    echo "Backup process finished at \$$(date)" # Escaped $
    exit 0
  BACKUP
    
    # Sleep for 1 minutes after creating the backup script
    echo "Sleeping for 1 minute..."
    sleep 60
    # Make the script executable
    chmod +x /scripts/backup.sh
    /scripts/backup.sh

    # Ensure gsutil is in the PATH for cron, or use full path: /snap/bin/gsutil or /usr/bin/gsutil
    # Adding PATH definition to cron job itself is often more reliable
    (crontab -l 2>/dev/null; echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"; echo "0 2 * * * /scripts/backup.sh >> /var/log/backup.log 2>&1") | crontab -
    
    echo "VM setup complete."
  STARTUP
  
  # Allow the startup script to finish before marking the instance as ready
  depends_on = [
    google_project_iam_member.db_vm_sa_editor_binding,
    google_storage_bucket.backup_bucket # Ensure bucket exists before script runs
  ]

  # Ensure SSH is enabled (usually default on Linux images)
  metadata = {
    enable-oslogin = "FALSE" # Use metadata-based SSH keys if needed, OS Login can interfere
  }
}
