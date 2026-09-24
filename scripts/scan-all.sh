#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${ACR_NAME:-myregistry.azurecr.io}"
APP_NAME="app"
TAG="${IMAGE_TAG:-1.0.0}"
SEVERITY="HIGH,CRITICAL"

echo "========================================="
echo "🛡️ Scanning Container Images with Trivy"
echo "Blocking Severity: ${SEVERITY}"
echo "========================================="

command -v trivy >/dev/null 2>&1 || {
  echo "⚠️ Trivy CLI is not installed locally. Running Trivy inside official Docker container..."
  TRIVY_CMD="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image"
}
TRIVY_CMD="${TRIVY_CMD:-trivy image}"

IMAGES=(
  "${REGISTRY}/${APP_NAME}/frontend:${TAG}"
  "${REGISTRY}/${APP_NAME}/backend:${TAG}"
  "${REGISTRY}/${APP_NAME}/auth:${TAG}"
  "${REGISTRY}/${APP_NAME}/worker:${TAG}"
)

FAIL_SCAN=0

for img in "${IMAGES[@]}"; do
  echo "🔍 Scanning image: ${img}..."
  if ! ${TRIVY_CMD} --severity "${SEVERITY}" --ignore-unfixed --exit-code 1 "${img}"; then
    echo "❌ High/Critical vulnerabilities detected in ${img}"
    FAIL_SCAN=1
  else
    echo "✅ Passed Trivy security scan: ${img}"
  fi
  echo "-----------------------------------------"
done

if [ "$FAIL_SCAN" -ne 0 ]; then
  echo "❌ One or more container images failed the security policy gate."
  exit 1
fi

echo "🎉 All container images passed vulnerability scan!"
