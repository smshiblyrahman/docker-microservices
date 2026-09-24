#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${ACR_NAME:-myregistry.azurecr.io}"
APP_NAME="app"
TAG="${IMAGE_TAG:-1.0.0}"

echo "========================================="
echo "🚀 Pushing Container Images to Azure Container Registry"
echo "ACR Registry: ${REGISTRY}"
echo "Tag:          ${TAG}"
echo "========================================="

# Ensure logged in if using az CLI
if command -v az >/dev/null 2>&1; then
  ACR_SERVER=$(echo "${REGISTRY}" | cut -d'.' -f1)
  echo "🔑 Authenticating to Azure Container Registry: ${ACR_SERVER}..."
  az acr login --name "${ACR_SERVER}" || echo "⚠️ Warning: az acr login returned non-zero, continuing with existing docker credentials..."
fi

IMAGES=(
  "${REGISTRY}/${APP_NAME}/frontend:${TAG}"
  "${REGISTRY}/${APP_NAME}/frontend:latest"
  "${REGISTRY}/${APP_NAME}/backend:${TAG}"
  "${REGISTRY}/${APP_NAME}/backend:latest"
  "${REGISTRY}/${APP_NAME}/auth:${TAG}"
  "${REGISTRY}/${APP_NAME}/auth:latest"
  "${REGISTRY}/${APP_NAME}/worker:${TAG}"
  "${REGISTRY}/${APP_NAME}/worker:latest"
)

for img in "${IMAGES[@]}"; do
  echo "⬆️ Pushing ${img}..."
  docker push "${img}"
done

echo "🎉 All images successfully pushed to ${REGISTRY}!"
