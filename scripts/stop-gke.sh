#!/usr/bin/env bash

set -e

# Ensure the script works regardless of the current directory.
cd "$(dirname "$0")/.."

echo "========================================"
echo "Stopping GitOps GKE environment"
echo "========================================"

echo
echo "Terraform will show the resources that will be destroyed."
echo "Review the plan carefully before confirming."
echo

terraform -chdir=infra/terraform destroy

echo
echo "GKE environment has been destroyed."
echo "Git repository remains intact."