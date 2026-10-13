#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <validated-image-git-sha>"
  exit 1
fi

IMAGE_TAG="$1"

if [[ ! "$IMAGE_TAG" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Error: image tag must be a 40-character lowercase Git SHA."
  exit 1
fi

STAGING_FILE="gitops/environments/staging/demo-app.yaml"

if ! grep -qE '^        image:$' "$STAGING_FILE" ||
   ! grep -qE '^          tag: "[0-9a-f]{40}"$' "$STAGING_FILE"; then
  echo "Error: expected staging image override/tag not found." >&2
  exit 1
fi

sed -i '/^        image:$/,/^  destination:$/ s|^          tag: "[0-9a-f]\{40\}"$|          tag: "'"$IMAGE_TAG"'"|' "$STAGING_FILE"

echo "Staging image tag updated to: $IMAGE_TAG"
echo "Review the change with: git diff -- $STAGING_FILE"
