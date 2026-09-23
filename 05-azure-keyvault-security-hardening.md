# Project 5 — Secure Secrets Management & Infrastructure Hardening

## SELISE-Oriented Technical Implementation Plan

## 1. Project Purpose

This project is the security layer across the infrastructure portfolio.

The supplied specification includes Azure Key Vault, private endpoints, soft-delete/purge protection, RBAC, rotation, AKS CSI integration, Azure DevOps integration, managed identities, NSGs, Azure Firewall, VPN Gateway, private endpoints, SSO, Conditional Access, MFA, Trivy, Azure Policy, security baselines, audit logging and compliance reporting. fileciteturn0file0L293-L350

SELISE's current SysOps requirements specifically emphasize security hardening, compliance audits, IAM, access reviews, configuration security, and policy making. citeturn0search0

## 2. Security Objectives

```text
Protect identities
Protect secrets
Reduce network exposure
Reduce permissions
Detect vulnerabilities
Enforce policies
Audit access
Rotate credentials
Recover safely
```

## 3. Architecture

```text
Developer / CI
      |
      v
Managed Identity
      |
      v
Azure Key Vault
   /    |     \
Secrets Keys Certificates
      |
Private Endpoint
      |
      v
      AKS
      |
 Key Vault CSI
      |
 Application
```

## 4. Secret Inventory

Classify:

```text
Database credentials
API keys
OAuth/client secrets
Certificates
Third-party credentials
Encryption keys
CI/CD credentials
```

For each secret document:

- Owner.
- Consumer.
- Sensitivity.
- Rotation period.
- Recovery procedure.

## 5. Key Vault

Configure:

- RBAC.
- Soft-delete.
- Purge protection.
- Private access where appropriate.
- Logging.
- Rotation policies.

The supplied project explicitly requires these controls. fileciteturn0file0L293-L300

## 6. Managed Identity

Preferred flow:

```text
Application
   |
Managed Identity
   |
Azure Authorization
   |
Key Vault
   |
Secret
```

This avoids application passwords.

## 7. AKS Integration

Use Key Vault CSI integration:

```text
Key Vault
   |
CSI Driver
   |
Pod
```

The original project specifically specifies mounting secrets into Kubernetes pods through this mechanism. fileciteturn0file0L301-L305

## 8. Network Security

Implement:

- NSGs.
- Azure Firewall where needed.
- Private Endpoints.
- VPN Gateway for secure remote access.
- Subnet isolation.

The goal is not simply to add firewall rules but to document allowed traffic paths.

Example:

```text
Internet
  X-> Database

Internet
  -> Load Balancer
  -> Application

Application
  -> Database

Application
  -> Key Vault
```

## 9. IAM Model

Use least privilege.

Example:

```text
Developer
  -> Dev resources

Operator
  -> Operational resources

Application identity
  -> Required runtime resources only

Security administrator
  -> Security configuration

Auditor
  -> Audit visibility
```

Conduct periodic access reviews.

## 10. Authentication Controls

The source includes:

- Azure AD integration.
- SSO.
- Conditional Access.
- MFA.
- Least privilege.
- Audit logging. fileciteturn0file0L317-L322

Document the difference between:

```text
Authentication = Who are you?
Authorization  = What can you do?
```

## 11. Security Scanning

The supplied project includes:

```bash
trivy image --severity HIGH,CRITICAL myapp:latest
tfsec .
kubesec scan deployment.yaml
```

Integrate these into CI.

Example:

```text
PR
 |
Terraform scan
 |
Kubernetes scan
 |
Dependency scan
 |
Container scan
 |
Quality gate
```

## 12. Azure Policy

Use policy to enforce organizational rules such as:

- Required tags.
- Approved regions.
- Encryption.
- Public-access restrictions.
- Required logging.
- Approved resource types.

The exact policies should be documented with their business purpose.

## 13. Secret Rotation

Safe rotation:

```text
Create new secret
       |
Store new version
       |
Update consumer
       |
Health check
       |
Revoke old version
       |
Audit
```

Test rotation before applying it to production.

## 14. CI/CD Secret Protection

Prevent secrets from entering:

- Git.
- Pipeline YAML.
- Logs.
- Artifacts.
- Docker images.

Use:

- Secret scanning.
- Pre-commit hooks.
- Key Vault.
- Masked pipeline variables where unavoidable.

## 15. Container Security

Use:

- Non-root containers.
- Minimal images.
- Trivy.
- Updated base images.
- Read-only filesystem where practical.
- Resource limits.

This connects Project 5 with Project 6.

## 16. Security Incident Response

If a credential leaks:

```text
Detect
 ↓
Disable/revoke credential
 ↓
Rotate secret
 ↓
Identify affected resources
 ↓
Review audit logs
 ↓
Contain
 ↓
Recover
 ↓
RCA
 ↓
Improve controls
```

The ability to respond matters as much as preventing the leak.

## 17. Compliance Evidence

Maintain:

```text
access-review records
policy results
security-scan results
rotation logs
audit logs
incident reports
configuration baselines
```

The original project mentions compliance reports and ISO 27001 alignment; do not claim formal certification unless it actually exists. fileciteturn0file0L324-L329

## 18. Implementation Plan

### Phase 1 — Inventory

Find all secrets and privileged identities.

### Phase 2 — Key Vault

Deploy and secure Key Vault.

### Phase 3 — Identity

Replace static credentials with managed identities.

### Phase 4 — AKS

Integrate CSI.

### Phase 5 — Network

Implement private endpoints and network segmentation.

### Phase 6 — Security Automation

Add Trivy, Terraform/IaC scanning, Kubernetes scanning, and policy checks.

### Phase 7 — Audit

Perform access review and incident simulation.

## 19. SELISE Alignment

This project directly demonstrates:

```text
IAM
RBAC
Least privilege
Security hardening
Compliance
Policy enforcement
Secrets management
Audit logging
Infrastructure security
Incident response
Automation
```

Those are directly relevant to the current SELISE SysOps role's security and governance responsibilities. citeturn0search0

## 20. Acceptance Criteria

```text
[ ] No hardcoded secrets
[ ] Key Vault protected
[ ] RBAC configured
[ ] Managed identities used
[ ] Private connectivity configured where required
[ ] MFA/Conditional Access documented
[ ] Security scans automated
[ ] Azure Policy rules documented
[ ] Audit logs available
[ ] Rotation tested
[ ] Credential-leak response documented
```

## 21. Interview Questions

1. Why Key Vault instead of environment variables?
2. What is managed identity?
3. RBAC vs access policies?
4. How do you rotate a production secret without downtime?
5. How would you respond to a leaked API key?
6. How do private endpoints improve security?
7. How do you prevent privilege creep?
8. How do you enforce security policy at scale?
9. How do you secure CI/CD credentials?
10. What evidence would you provide during a security audit?
