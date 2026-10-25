#!/usr/bin/env bash

set -e

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

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v3.5.3"

echo "========================================"
echo "Starting GitOps GKE environment"
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

echo "==> Terraform apply"
if [[ "$GITHUB_ACTIONS_MODE" == "true" ]]; then
  terraform -chdir=infra/terraform apply -input=false -auto-approve
else
  terraform -chdir=infra/terraform apply
fi

echo "==> Configuring kubectl"
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$CLUSTER_ZONE" \
  --project "$PROJECT_ID"

echo "==> Verifying GKE node"
kubectl get nodes

echo
echo "==> Checking Argo CD"

if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    echo "Argo CD namespace already exists."
else
    echo "Installing Argo CD $ARGOCD_VERSION..."
    kubectl create namespace "$ARGOCD_NAMESPACE"

    kubectl apply --server-side -n "$ARGOCD_NAMESPACE" \
      -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
fi

echo "==> Ensuring Argo CD ApplicationSet CRD"

ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
ARGOCD_MANIFEST="$(mktemp)"
trap 'rm -f "$ARGOCD_MANIFEST" /tmp/applicationset-crd.yaml' EXIT

curl -fsSL "$ARGOCD_MANIFEST_URL" -o "$ARGOCD_MANIFEST"

awk '
  /^---[[:space:]]*$/ {
    if (doc ~ /kind: CustomResourceDefinition/ && doc ~ /name: applicationsets\.argoproj\.io/) {
      printf "%s", doc
      found = 1
      exit
    }
    doc = ""
    next
  }
  { doc = doc $0 "\n" }
  END {
    if (!found && doc ~ /kind: CustomResourceDefinition/ && doc ~ /name: applicationsets\.argoproj\.io/) {
      printf "%s", doc
      found = 1
    }
    if (!found) exit 1
  }
' "$ARGOCD_MANIFEST" > /tmp/applicationset-crd.yaml

test -s /tmp/applicationset-crd.yaml
kubectl apply --server-side -f /tmp/applicationset-crd.yaml

echo "==> Waiting for Argo CD server"
kubectl rollout status deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=180s

echo "==> Verifying Argo CD"
kubectl get pods -n "$ARGOCD_NAMESPACE"

echo
echo "==> Restoring GitOps Applications"

echo
echo "==> Configuring Grafana SMTP credentials"

kubectl create namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

if [[ "$GITHUB_ACTIONS_MODE" == "true" ]]; then
  GMAIL_USER="${GMAIL_USER:-}"
  GMAIL_APP_PASSWORD="${GMAIL_APP_PASSWORD:-}"
else
  read -r -p "Gmail address: " GMAIL_USER
  read -r -s -p "Gmail App Password: " GMAIL_APP_PASSWORD
  echo
fi

echo

if [[ -z "$GMAIL_USER" || -z "$GMAIL_APP_PASSWORD" ]]; then
  echo "ERROR: Gmail address and app password are required."
  unset GMAIL_USER GMAIL_APP_PASSWORD
  exit 1
fi

kubectl create secret generic grafana-smtp \
  -n monitoring \
  --from-literal=username="$GMAIL_USER" \
  --from-literal=password="$GMAIL_APP_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

unset GMAIL_USER GMAIL_APP_PASSWORD

kubectl apply -f gitops/applicationset.yaml
kubectl apply -f observability/prometheus/environments/dev/prometheus.yaml
kubectl apply -f observability/grafana/environments/dev/grafana.yaml
kubectl apply -f observability/loki/environments/dev/loki.yaml
kubectl apply -f observability/promtail/environments/dev/promtail.yaml

echo
echo "GKE environment is ready."
