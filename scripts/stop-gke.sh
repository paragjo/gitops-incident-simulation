#!/usr/bin/env bash

set -e

# Ensure the script works regardless of the current directory.
cd "$(dirname "$0")/.."

GITHUB_ACTIONS_MODE="${GITHUB_ACTIONS:-false}"

if [[ "$GITHUB_ACTIONS_MODE" == "true" ]]; then
  : "${GCP_PROJECT_ID:?GCP_PROJECT_ID must be configured}"
  : "${GCP_REGION:?GCP_REGION must be configured}"
  : "${GCP_ZONE:?GCP_ZONE must be configured}"
  : "${GCP_CLUSTER_NAME:?GCP_CLUSTER_NAME must be configured}"

  PROJECT_ID="$GCP_PROJECT_ID"
  REGION="$GCP_REGION"
  CLUSTER_ZONE="$GCP_ZONE"
  CLUSTER_NAME="$GCP_CLUSTER_NAME"
else
  PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
  REGION="${GCP_REGION:-asia-south1}"
  CLUSTER_ZONE="${GCP_ZONE:-asia-south1-a}"
  CLUSTER_NAME="${GCP_CLUSTER_NAME:-gitops-gke}"
fi

export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_region="$REGION"
export TF_VAR_zone="$CLUSTER_ZONE"
export TF_VAR_cluster_name="$CLUSTER_NAME"

echo "========================================"
echo "Stopping GitOps GKE environment"
echo "========================================"

echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo

echo "==> Terraform init"
if [[ "$GITHUB_ACTIONS_MODE" == "true" ]]; then
  terraform -chdir=infra/terraform init -input=false
else
  terraform -chdir=infra/terraform init
fi

echo
echo "Terraform will show the resources that will be destroyed."
echo "Review the plan carefully before confirming."
echo

if [[ "$GITHUB_ACTIONS_MODE" == "true" ]]; then
  terraform -chdir=infra/terraform destroy \
    -input=false \
    -auto-approve \
    -target=google_container_node_pool.gitops \
    -target=google_container_cluster.gitops \
    -target=google_compute_subnetwork.gitops \
    -target=google_compute_network.gitops
else
  terraform -chdir=infra/terraform destroy \
    -target=google_container_node_pool.gitops \
    -target=google_container_cluster.gitops \
    -target=google_compute_subnetwork.gitops \
    -target=google_compute_network.gitops
fi

echo
echo "GKE infrastructure has been destroyed."
echo "Persistent GitHub Actions identity and Terraform state are retained."
echo "Git repository remains intact."
