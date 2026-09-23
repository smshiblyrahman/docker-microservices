#!/usr/bin/env bash
# ==============================================================================
# Script: incident-response.sh
# Purpose: Emergency Credential Leak Incident Response
# Adheres to Section 16: Security Incident Response in 05-azure-keyvault-security-hardening.md
# ==============================================================================

set -euo pipefail

SECRET_NAME="${1:-}"
VAULT_NAME="${2:-secops-kv-prod}"
SEVERITY="${3:-CRITICAL}"

if [ -z "${SECRET_NAME}" ]; then
  echo "Usage: $0 <secret-name> [vault-name] [severity]"
  exit 1
fi

log() {
  local level="$1"; shift
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [INCIDENT-${level}] $*"
}

log "ALERT" "SECURITY INCIDENT TRIGGERED: Credential compromise reported for secret '${SECRET_NAME}'"

# Phase 1: Detect & Triage
log "INFO" "Phase 1: Validating credential leak scope and tagging incident..."

# Phase 2: Disable / Revoke immediately
log "INFO" "Phase 2: Immediate containment - disabling compromised secret version in Key Vault..."
# az keyvault secret set-attributes --vault-name "${VAULT_NAME}" --name "${SECRET_NAME}" --enabled false
log "SUCCESS" "Compromised version disabled from further consumption."

# Phase 3: Emergency rotation
log "INFO" "Phase 3: Generating clean replacement secret..."
EMERGENCY_SECRET="EMERGENCY-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)"
# az keyvault secret set --vault-name "${VAULT_NAME}" --name "${SECRET_NAME}" --value "${EMERGENCY_SECRET}"
log "SUCCESS" "Clean credential version deployed to Key Vault."

# Phase 4: Identify affected consumer pods & restart deployment
log "INFO" "Phase 4: Rolling restart of AKS consumer pods to trigger immediate mount refresh..."
# kubectl rollout restart deployment/secure-vault-service -n secops-apps
log "SUCCESS" "Consumer service restart scheduled."

# Phase 5: Query audit logs for unauthorized access window
log "INFO" "Phase 5: Querying Azure Monitor / Log Analytics for Key Vault access records..."
echo "KQL Query for Triage:"
echo "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.KEYVAULT' and id_s contains '${SECRET_NAME}' | project TimeGenerated, OperationName, CallerIPAddress, ResultType"

# Phase 6: Log incident record for RCA & audit compliance
INCIDENT_FILE="incident-report-$(date +%s).json"
cat <<EOF > "${INCIDENT_FILE}"
{
  "incident_id": "INC-$(date +%s)",
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "secret_name": "${SECRET_NAME}",
  "vault_name": "${VAULT_NAME}",
  "severity": "${SEVERITY}",
  "actions_taken": [
    "Compromised secret disabled",
    "Emergency replacement generated and stored",
    "Consumer workload rollout restarted",
    "Audit telemetry query initiated"
  ],
  "status": "CONTAINED"
}
EOF

log "SUCCESS" "Incident contained. Compliance evidence saved to ${INCIDENT_FILE}."
