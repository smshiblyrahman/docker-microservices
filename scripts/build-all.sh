#!/usr/bin/env bash
set -euo pipefail

# Configuration
REGISTRY="${ACR_NAME:-myregistry.azurecr.io}"
APP_NAME="app"
TAG="${IMAGE_TAG:-1.0.0}"

echo "========================================="
echo "🔨 Building Multi-Stage Microservices"
echo "Registry: ${REGISTRY}/${APP_NAME}"
echo "Tag:      ${TAG}"
echo "========================================="

# Enable BuildKit for parallel and cached multi-stage builds
export DOCKER_BUILDKIT=1

echo "📦 1/4 Building Frontend Image..."
docker build \
  --file frontend/Dockerfile \
  --tag "${REGISTRY}/${APP_NAME}/frontend:${TAG}" \
  --tag "${REGISTRY}/${APP_NAME}/frontend:latest" \
  frontend/

echo "📦 2/4 Building Backend Image..."
docker build \
  --file backend/Dockerfile \
  --tag "${REGISTRY}/${APP_NAME}/backend:${TAG}" \
  --tag "${REGISTRY}/${APP_NAME}/backend:latest" \
  backend/

echo "📦 3/4 Building Auth Service Image..."
docker build \
  --file auth-service/Dockerfile \
  --tag "${REGISTRY}/${APP_NAME}/auth:${TAG}" \
  --tag "${REGISTRY}/${APP_NAME}/auth:latest" \
  auth-service/

echo "📦 4/4 Building Celery Worker Image..."
docker build \
  --file worker/Dockerfile \
  --tag "${REGISTRY}/${APP_NAME}/worker:${TAG}" \
  --tag "${REGISTRY}/${APP_NAME}/worker:latest" \
  worker/

echo "✅ All microservice images built successfully!"
docker images | grep "${REGISTRY}/${APP_NAME}" || true
