# 0001. Secure Secrets Management and Key Vault Infrastructure Hardening

**Date**: 2026-09-23
**Status**: Proposed

## Summary

This architecture implements end to end secrets management and hardening for Azure Key Vault, AKS, and developer pipelines. Static passwords and secrets in code or git are eliminated by using Azure Managed Identity, Azure AD Workload Identity, and the Secrets Store CSI driver. Infrastructure is provisioned through Terraform with private endpoints, strict RBAC, soft delete, and purge protection enabled. Automated scanning and rotation scripts enforce continuous compliance with zero trust principles.

## Context

Managing credentials directly in application source code, configuration files, or container images creates critical attack vectors and privilege creep. Organizations operating cloud infrastructure need isolated secrets vaults, granular access reviews, automated credential rotation, and container level least privilege. 

Without a centralized secrets manager and workload identity architecture, credentials become permanent, difficult to rotate, and easily leaked across pipeline logs and git commits. The system must meet strict audit logging, access review, and network isolation requirements without disrupting production application availability.

## Requirements

**User stories**:
- As a DevOps engineer, I want infrastructure as code for Azure Key Vault with private endpoints, RBAC, and purge protection so that secrets remain isolated from the public internet and protected from malicious deletion.
- As a backend developer, I want my containerized service on AKS to consume Key Vault secrets automatically via Workload Identity and Secrets Store CSI driver so that no application credentials exist in plain text or environment variables.
- As a security auditor, I want automated rotation scripts, CI/CD vulnerability scanning, and IAM access reviews so that credentials rotate safely and compliance evidence is readily retrievable.

**Acceptance criteria**:
- **AC-1**: Key Vault Terraform configuration enforces soft delete retention (90 days), purge protection enabled, RBAC authorization mode, and public network access disabled.
- **AC-2**: Key Vault Private Endpoint and Private DNS Zone are provisioned with virtual network integration and network security group restrictions.
- **AC-3**: Application microservice mounts secrets into container file paths using AKS Secrets Store CSI driver and Azure AD Workload Identity with zero static credentials.
- **AC-4**: Node.js application reads secrets securely from mount paths (`/mnt/secrets-store`), handles secret cache reload, and provides health and audit status endpoints.
- **AC-5**: Secret rotation script demonstrates automated zero downtime rotation with version verification, health check confirmation, and old version deprecation.
- **AC-6**: CI pipeline definition validates code and infrastructure through security linters, container scanning, and pre-commit secret detection.
- **AC-7**: Emergency credential leak incident response script provides instant revocation and rotation trigger procedures.

## Options considered

### Option 1: Azure Key Vault with Secrets Store CSI Driver and Workload Identity

Uses Azure native Key Vault with RBAC permissions, Azure AD Workload Identity for pod level identity federation, and Kubernetes Secrets Store CSI driver for dynamic file mounting.

**Pros**:
- Zero long lived secrets stored in pod specifications or git
- Fine grained pod level Azure RBAC access
- Secrets update automatically on rotation interval without restarting pods

**Cons**:
- Requires AKS CSI driver add on and Workload Identity webhook enabled

### Option 2: Kubernetes Native Secrets populated via CI/CD pipelines

Secrets injected into Kubernetes Secret objects during CI/CD execution from pipeline variables.

**Pros**:
- Simple Kubernetes native consumption

**Cons**:
- Secrets stored in etcd (often unencrypted at rest)
- Broad cluster scope access risk and high potential for pipeline log leaks

## Decision

**Chosen option**: Option 1: Azure Key Vault with Secrets Store CSI Driver and Workload Identity.

This option eliminates static credentials completely, supports automated rotation, and adheres to zero trust least privilege principles.

**Implementation skills**: `architect` (`jsmastery-pro/skills`, `.agents/skills/architect/`) · `develop` (`jsmastery-pro/skills`, `.agents/skills/develop/`)

## Rationale

Storing secrets in application manifests or pipeline variables violates baseline security objectives. Secrets Store CSI driver combined with Azure AD Workload Identity delivers true end to end security where only the authorized pod identity receives a short lived federated token to read specific secret versions mounted as memory backed tmpfs volumes.

## Feature design

**Data model sketch**:
- Secret Inventory:
  - `DatabaseCredentials`: connection string, rotated every 60 days
  - `ApiKey`: third party API token, rotated every 90 days
  - `TlsCertificate`: ingress HTTPS certificate, rotated annually

**API surface**:
| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| /health | GET | None | status, timestamp | None | 503 service unavailable |
| /api/config | GET | None | loaded_keys, secret_checksum, last_read | Bearer token | 401 unauthorized |
| /api/data | GET | None | success, payload | Bearer token | 500 secret unavailable |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Read secret | Database password / API Key | Mounted tmpfs file at `/mnt/secrets-store/*` synced from Key Vault |
| Health check | Vault connectivity status | File existence check and timestamp validation at `/mnt/secrets-store` |
| Rotate secret | New secret version | Key Vault API via rotation automation script |

**Key invariants**:
- Plaintext secrets must never be printed to stdout, stderr, or logged to application telemetry.
- Application must read secrets from mounted volume files rather than permanent disk storage.
- Key Vault purge protection cannot be disabled once set.

**Security model**:
- Azure RBAC: `Key Vault Secrets User` role assigned strictly to the AKS Workload Managed Identity.
- Network: Key Vault accessible only through Private Endpoint on designated AKS subnet.
- Container: Non root user execution (UID 10001), read only root filesystem, dropped Linux capabilities.

**Configuration required**:
- `AZURE_KEYVAULT_NAME`: Target vault name
- `KEYVAULT_SECRET_PATH`: Mount directory (default: `/mnt/secrets-store`)
- `PORT`: Service listen port (default: 3000)

**Critical test scenarios**:
- Happy path: Container starts, CSI driver mounts secret files, application reads secret and reports healthy status, verifies **AC-3**, **AC-4**.
- Failure case: Secret file unreadable or missing, application fails health check with 503 and logs structured alert, verifies **AC-4**.
- Auth/permission: Unauthorized client accessing config endpoint receives 401 Unauthorized, verifies **AC-4**.
- Rotation lifecycle: Secret rotation script updates Key Vault, CSI driver auto refreshes file, application reloads updated value without crash, verifies **AC-5**.

## Build plan

1. Provision Terraform infrastructure modules (`terraform/`) for VNet, Subnets, Key Vault with Private Endpoint, RBAC, and AKS configuration, satisfies **AC-1**, **AC-2**.
2. Configure Kubernetes SecretProviderClass and workload deployment manifests (`k8s/`) with Workload Identity service accounts and CSI volume mounts, satisfies **AC-3**.
3. Implement hardened Node.js microservice (`app/`) reading mounted secrets with automated reload, health checks, and non root Dockerfile, satisfies **AC-3**, **AC-4**.
4. Create secret rotation and lifecycle automation script (`scripts/rotate-secret.sh`), satisfies **AC-5**.
5. Create emergency credential leak incident response script (`scripts/incident-response.sh`), satisfies **AC-7**.
6. Set up CI/CD pipeline workflow (`.github/workflows/security-ci.yml`) enforcing Trivy, IaC security scanning, and pre-commit secret detection, satisfies **AC-6**.

## Consequences

**Positive**:
- Zero plaintext secrets in code or cluster git repositories.
- Automatic rotation detection without container restarts.
- Full compliance and audit trail through Azure Monitor and Key Vault diagnostic logs.

**Negative / tradeoffs**:
- Requires Kubernetes Secrets Store CSI driver pod overhead on each cluster node.
- Private endpoints require internal network routing or jumpbox for developer debugging.

## Follow-up

- [ ] Connect Azure Monitor Diagnostic Settings to Log Analytics Workspace for alerts on HTTP 401 and 403 access attempts.
- [ ] Implement Azure Policy initiative to deny creation of Key Vaults without purge protection and soft delete.
