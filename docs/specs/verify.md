# Verify: Key Vault Security Hardening · spec 0001 · updated 2026-09-23
_Steps derived from spec 0001 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## Commands
- [x] `cd app && npm test` → Unit tests pass (health, loadSecrets, rotation) → AC-3, AC-4
- [x] `./scripts/rotate-secret.sh secops-kv-prod db-password http://localhost:3000/health` → Exit code 0, rotation logged → AC-5
- [x] `./scripts/incident-response.sh api-key secops-kv-prod CRITICAL` → Exit code 0, incident JSON generated → AC-7
- [ ] `terraform validate` in `terraform/` → Configuration syntax and references valid → AC-1, AC-2

## Acceptance-criteria coverage
- AC-1: Covered by `terraform/main.tf` soft-delete, purge protection, RBAC, public access disabled
- AC-2: Covered by `terraform/main.tf` Private Endpoint, Private DNS Zone, NSG rules
- AC-3: Covered by `k8s/deployment.yaml` SecretProviderClass & Workload Identity serviceAccount
- AC-4: Covered by `app/server.js` and `app/test.js`
- AC-5: Covered by `scripts/rotate-secret.sh`
- AC-6: Covered by `.github/workflows/security-ci.yml`
- AC-7: Covered by `scripts/incident-response.sh`
