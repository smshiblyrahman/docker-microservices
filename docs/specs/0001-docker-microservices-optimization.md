# 0001. Containerization & Optimization for Multi-Service Microservices Stack

**Date**: 2026-09-24
**Status**: In Progress

## Summary

This architecture specifies an end to end containerized microservices application optimized for size, speed, security, and Kubernetes readiness. It defines four custom application services (React frontend, Flask backend API, Node.js authentication service, Celery async worker) and two managed data stores (PostgreSQL and Redis). All containers use multi-stage minimal builds, non-root execution, resource limits, health checks, and Docker Compose environments for local development and production.

## Context

Enterprise architectures require microservices with independent deployment pipelines, minimal resource consumption, and defense in depth container security. Legacy monolithic applications often suffer from multi-gigabyte container images, slow CI/CD deployments, excessive attack surfaces, root privileges inside containers, and broken container orchestration dependencies.

To achieve production excellence aligned with SELISE DevOps standards, this system requires:
1. Drastic image size reductions using multi-stage builds and Alpine or slim base layers.
2. Hardened container runtimes (non-root users, explicit read-only file systems, and minimal write volumes).
3. Dependency readiness verification (health checks with retries rather than naive start ordering).
4. Automated security scanning with Trivy and reproducible local and production Docker Compose profiles.

## Requirements

**User stories**:
- As a developer, I want a single command local development environment with hot reloading and dependency health checks so that I can develop microservices reliably.
- As a DevOps engineer, I want optimized multi-stage production Docker images and vulnerability scanning scripts so that deployments to Azure Container Registry and Kubernetes are secure and lightweight.
- As an end user, I want a responsive web UI that authenticates through a dedicated auth service and processes tasks asynchronously via background workers.

**Acceptance criteria**:
- **AC-1**: Every custom service (frontend, backend, auth-service, worker) has an optimized multi-stage production Dockerfile and minimal build context via `.dockerignore`.
- **AC-2**: All application containers run as unprivileged non-root users (`node`, `appuser`, `celeryuser`) with explicit UID/GID settings.
- **AC-3**: Every service exposes a lightweight deterministic health check endpoint (`/health` or CLI check) and Docker Compose configuration declares `condition: service_healthy` readiness checks.
- **AC-4**: Production Docker Compose configuration (`docker-compose.prod.yml`) enforces CPU and memory limits, logging rate limits, and read-only container root filesystems where applicable.
- **AC-5**: Automated scripts exist for building all images, scanning images with Trivy (blocking HIGH and CRITICAL vulnerabilities), and tagging for Azure Container Registry (ACR) semantic versioning.
- **AC-6**: Full end to end application functionality works: User registers/logs in via Auth Service, accesses protected endpoints via Flask API, and dispatches background tasks to Celery worker via Redis broker.

## Options considered

### Option 1: Monolithic Container with Single Process Supervisor
Package React build, Flask API, and Node services inside an Ubuntu base container with systemd or supervisord.

**Pros**:
- Single container image to build and deploy.

**Cons**:
- Enormous image size (>1.5 GB), violates microservice independence, prevents granular autoscaling, violates single concern container principle.

### Option 2: Full Microservices Stack with Multi-Stage Slim/Alpine Containers (Chosen)
Separate repositories/directories for Frontend (React/Nginx), Backend (Flask), Auth Service (Node.js/Express), and Worker (Celery/Redis), using official Alpine or slim bases and multi-stage compilation.

**Pros**:
- Independent scaling, minimal attack surface, image sizes reduced under 150 MB, strict isolation of dependencies.

**Cons**:
- Requires orchestration, network configuration, and dependency health wait loops.

## Decision

**Chosen option**: Option 2: Full Microservices Stack with Multi-Stage Slim/Alpine Containers.

We deploy independent multi-stage container images for Frontend, Backend, Auth, and Worker with Docker Compose orchestration.

## Feature design

**Data model sketch**:
- `users` (id UUID PK, email VARCHAR UNIQUE, password_hash VARCHAR, full_name VARCHAR, created_at TIMESTAMP)
- `tasks` (id UUID PK, user_id UUID FK, task_type VARCHAR, status VARCHAR, payload JSONB, result JSONB, created_at TIMESTAMP, updated_at TIMESTAMP)

**API surface**:
| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| /api/auth/register | POST | email, password, full_name | user object, token | Public | 400 invalid, 409 email taken |
| /api/auth/login | POST | email, password | token, user object | Public | 401 invalid credentials |
| /api/auth/verify | GET | Header: Authorization | valid boolean, user claims | Bearer token | 401 unauthorized |
| /api/tasks | POST | task_type, payload | task_id, status | Bearer token | 400 invalid, 401 unauthorized |
| /api/tasks/{id} | GET | id in path | task details, result, status | Bearer token | 404 not found, 401 unauthorized |
| /health | GET | none | status: "healthy", timestamp | Public | 500 service degraded |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Register user | User ID and password hash | Auth service generates UUID; hashes password with bcrypt |
| Issue JWT | Access token with claims | Auth service signs JWT with HMAC-SHA256 using JWT_SECRET |
| Create async task | Celery Task ID and Queued Status | Flask API dispatches task to Redis broker via Celery client |
| Process task | Task calculation result | Celery worker executes math/transform task and updates Redis result backend |

**Key invariants**:
- Passwords must never be stored in plain text.
- Frontend talks to Flask API and Auth Service via reverse proxy routes or Docker internal network DNS.
- Containers must never write outside designated volume mounts when `read_only: true` is configured.

**Security model**:
- Non-root users inside all container stages (`USER 10001:10001` or `USER node`).
- Secrets provided through environment variables or Docker Secrets files, never baked into container layers.
- Resource limits constrain memory (e.g. 128MB to 512MB) and CPU (0.25 to 1.0 CPU) per container.

**Configuration required**:
- `PORT`: Service listen port
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `JWT_SECRET`: Secret key for token signing
- `ACR_NAME`: Azure Container Registry hostname for tagging and pushing

**Critical test scenarios**:
- Happy path: User signs up on React UI, receives JWT, submits background data processing task, Celery worker finishes task, UI displays completed result (verifies **AC-1**, **AC-3**, **AC-6**).
- Failure case: Database or Redis is temporarily down; health check fails and dependent services wait with retries until dependency is healthy (verifies **AC-3**).
- Security scan: Trivy vulnerability scan passes with zero HIGH or CRITICAL unfixed vulnerabilities (verifies **AC-5**).

## Build plan

1. Create `.dockerignore` and multi-stage `Dockerfile` for Auth Service (Node.js/Express, non-root `node` user), satisfies **AC-1**, **AC-2**, **AC-3**.
2. Create `.dockerignore` and multi-stage `Dockerfile` for Backend Service (Flask, Python 3.11-slim, Gunicorn, non-root `appuser`), satisfies **AC-1**, **AC-2**, **AC-3**.
3. Create `.dockerignore` and multi-stage `Dockerfile` for Celery Worker (Python 3.11-slim, Redis integration, non-root `celeryuser`), satisfies **AC-1**, **AC-2**, **AC-3**.
4. Create `.dockerignore` and multi-stage `Dockerfile` for Frontend (Node build stage, Nginx unprivileged Alpine runtime stage), satisfies **AC-1**, **AC-2**, **AC-3**.
5. Create `docker-compose.yml` for local development with dependency health checks and volume mounts, satisfies **AC-3**, **AC-6**.
6. Create `docker-compose.prod.yml` with security hardening, resource limits, read-only filesystems, and logging drivers, satisfies **AC-4**.
7. Create deployment and automation scripts (`scripts/build-all.sh`, `scripts/scan-all.sh`, `scripts/push-all.sh`), satisfies **AC-5**.
8. Build and verify test suite and health check endpoints end to end, satisfies **AC-6**.

## Consequences

**Positive**:
- Image size reduced by up to 88% compared to standard monolithic bases.
- Zero root container execution prevents container breakout risks.
- Layer cache optimization cuts rebuild times significantly.
- Direct alignment with Kubernetes manifests and CI/CD pipelines.

**Negative / tradeoffs**:
- Read-only filesystems require explicit tmpfs or volume definitions for temporary files and caches.
- Multi-service composition requires orchestration overhead and health check coordination.
