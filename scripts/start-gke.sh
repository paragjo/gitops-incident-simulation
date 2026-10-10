#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/.."

PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
CLUSTER_NAME="gitops-gke"
CLUSTER_ZONE="asia-south1-a"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v3.5.3"

echo "========================================"
echo "Starting GitOps GKE environment"
echo "========================================"

echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo

echo "==> Terraform init"
terraform -chdir=infra/terraform init

echo "==> Terraform apply"
terraform -chdir=infra/terraform apply

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

curl -fsSL "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"   | sed -n '7114,/^---$/p'   > /tmp/applicationset-crd.yaml

kubectl apply --server-side -f /tmp/applicationset-crd.yaml

echo "==> Waiting for Argo CD server"
kubectl rollout status deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=180s

echo "==> Verifying Argo CD"
kubectl get pods -n "$ARGOCD_NAMESPACE"

echo
echo "==> Restoring GitOps Applications"

kubectl apply -f gitops/environments/dev/demo-app.yaml
kubectl apply -f observability/prometheus/environments/dev/prometheus.yaml
kubectl apply -f observability/grafana/environments/dev/grafana.yaml
kubectl apply -f observability/loki/environments/dev/loki.yaml
kubectl apply -f observability/promtail/environments/dev/promtail.yaml

echo
echo "GKE environment is ready."
