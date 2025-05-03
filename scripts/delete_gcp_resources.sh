#!/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Set these variables correctly !!!
PROJECT_ID="clgcporg10-183"
REGION="us-central1"
ZONE="us-central1-a"
# !!! IMPORTANT: Replace this with the EXACT unique name of the bucket created !!!
STORAGE_BUCKET_NAME="wiz-exercise-backups-clgcporg10-183" # <--- REPLACE THIS

# --- Resource Names (Based on variables.tf defaults) ---
NETWORK_NAME="wiz-vpc"
SUBNET_NAME="public-subnet"
PRIVATE_SUBNET_NAME="private-subnet"
DB_SERVER_TAG="db-server"
GKE_NODES_TAG="gke-node"
CLOUD_ROUTER_NAME="wiz-router"
DB_VM_NAME="mongodb-vm"
DB_VM_SA_NAME="db-vm-overly-permissive-sa" # This is the account_id, not the full email
GKE_CLUSTER_NAME="wiz-cluster"
AR_REPO_NAME="wiz-app-repo"

# Construct derived names
DB_VM_SA_EMAIL="${DB_VM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
FIREWALL_SSH="${NETWORK_NAME}-allow-ssh-external"
FIREWALL_MONGO="${NETWORK_NAME}-allow-mongo-from-gke"
FIREWALL_EGRESS="${NETWORK_NAME}-allow-egress-all"
FIREWALL_HEALTH="${NETWORK_NAME}-allow-gcp-health-checks"
FIREWALL_HTTP="${NETWORK_NAME}-allow-http-https-external"
NAT_GATEWAY_NAME="${NETWORK_NAME}-nat-gateway"
GKE_NODE_POOL_NAME="${GKE_CLUSTER_NAME}-node-pool"

# --- Safety Check ---
echo "---------------------------------------------------------------------"
echo "WARNING: This script will attempt to permanently delete resources"
echo "in project '$PROJECT_ID' based on the Terraform configuration."
echo "---------------------------------------------------------------------"
echo "Project ID:          $PROJECT_ID"
echo "Region:              $REGION"
echo "Zone:                $ZONE"
echo "Network:             $NETWORK_NAME"
echo "GKE Cluster:         $GKE_CLUSTER_NAME"
echo "DB VM:               $DB_VM_NAME"
echo "DB VM SA:            $DB_VM_SA_EMAIL"
echo "Artifact Repo:       $AR_REPO_NAME"
echo "Storage Bucket:      $STORAGE_BUCKET_NAME"
echo "---------------------------------------------------------------------"
read -p "Are you absolutely sure you want to proceed? (yes/no): " confirmation
if [[ "$confirmation" != "yes" ]]; then
    echo "Aborting deletion."
    exit 1
fi
echo "Proceeding with deletion..."
echo "---------------------------------------------------------------------"


# --- Deletion Order ---

# 1. GKE Cluster (deletes Node Pool automatically)
echo "Deleting GKE Cluster '$GKE_CLUSTER_NAME' (this can take several minutes)..."
gcloud container clusters delete "$GKE_CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete GKE cluster (might not exist or error)."

# 2. Compute Instance
echo "Deleting Compute Instance '$DB_VM_NAME'..."
gcloud compute instances delete "$DB_VM_NAME" \
    --zone="$ZONE" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Compute Instance (might not exist or error)."

# 3. Cloud NAT
echo "Deleting Cloud NAT Gateway '$NAT_GATEWAY_NAME'..."
gcloud compute routers nats delete "$NAT_GATEWAY_NAME" \
    --router="$CLOUD_ROUTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Cloud NAT Gateway (might not exist or error)."

# 4. Cloud Router
echo "Deleting Cloud Router '$CLOUD_ROUTER_NAME'..."
gcloud compute routers delete "$CLOUD_ROUTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Cloud Router (might not exist or error)."

# 5. Firewall Rules
echo "Deleting Firewall Rule '$FIREWALL_SSH'..."
gcloud compute firewall-rules delete "$FIREWALL_SSH" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete firewall rule '$FIREWALL_SSH'."

echo "Deleting Firewall Rule '$FIREWALL_MONGO'..."
gcloud compute firewall-rules delete "$FIREWALL_MONGO" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete firewall rule '$FIREWALL_MONGO'."

echo "Deleting Firewall Rule '$FIREWALL_EGRESS'..."
gcloud compute firewall-rules delete "$FIREWALL_EGRESS" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete firewall rule '$FIREWALL_EGRESS'."

echo "Deleting Firewall Rule '$FIREWALL_HEALTH'..."
gcloud compute firewall-rules delete "$FIREWALL_HEALTH" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete firewall rule '$FIREWALL_HEALTH'."

echo "Deleting Firewall Rule '$FIREWALL_HTTP'..."
gcloud compute firewall-rules delete "$FIREWALL_HTTP" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete firewall rule '$FIREWALL_HTTP'."

# 6. Subnets (Must be deleted before the network)
echo "Deleting Subnet '$PRIVATE_SUBNET_NAME'..."
gcloud compute networks subnets delete "$PRIVATE_SUBNET_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete subnet '$PRIVATE_SUBNET_NAME'."

echo "Deleting Subnet '$SUBNET_NAME'..."
gcloud compute networks subnets delete "$SUBNET_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete subnet '$SUBNET_NAME'."

# 7. VPC Network (Must be deleted after all dependent resources)
echo "Deleting VPC Network '$NETWORK_NAME'..."
gcloud compute networks delete "$NETWORK_NAME" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete network '$NETWORK_NAME'."

# 8. Artifact Registry Repository
echo "Deleting Artifact Registry Repository '$AR_REPO_NAME'..."
gcloud artifacts repositories delete "$AR_REPO_NAME" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Artifact Registry repository '$AR_REPO_NAME'."

# 9. Storage Bucket (Requires emptying first)
echo "Deleting contents of Storage Bucket '$STORAGE_BUCKET_NAME'..."
# Use gsutil rm -r for recursive delete. Add -f to force if needed.
gsutil -m rm -r "gs://${STORAGE_BUCKET_NAME}/**" || echo "Warning: Failed to empty bucket '$STORAGE_BUCKET_NAME' (might be empty or error)."

echo "Deleting Storage Bucket '$STORAGE_BUCKET_NAME'..."
gcloud storage buckets delete "gs://${STORAGE_BUCKET_NAME}" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Storage Bucket '$STORAGE_BUCKET_NAME'."
# Note: Bucket IAM bindings are deleted with the bucket.

# 10. IAM Project Binding for DB VM SA
echo "Removing IAM project binding for '$DB_VM_SA_EMAIL' (Role: roles/editor)..."
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${DB_VM_SA_EMAIL}" \
    --role="roles/editor" \
    --quiet || echo "Warning: Failed to remove IAM binding for '$DB_VM_SA_EMAIL'."

# 11. Service Account for DB VM
echo "Deleting Service Account '$DB_VM_SA_EMAIL'..."
gcloud iam service-accounts delete "$DB_VM_SA_EMAIL" \
    --project="$PROJECT_ID" \
    --quiet || echo "Warning: Failed to delete Service Account '$DB_VM_SA_EMAIL'."

echo "---------------------------------------------------------------------"
echo "Deletion script finished. Please check the GCP Console for any remaining resources or errors."
echo "---------------------------------------------------------------------"
