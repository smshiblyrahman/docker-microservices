# Verify: End-to-End Containerized Microservices Application · spec 0001 · updated 2026-09-24
_Steps derived from spec 0001 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## Automated & Container Build Checks
- [ ] Build all multi-stage containers via `./scripts/build-all.sh` → All 4 images build without errors → AC-1
- [ ] Inspect container user IDs: verify none run as root (`docker run --rm <image> id`) → AC-2
- [ ] Start development stack with `docker compose up -d` → All services transition to healthy → AC-3
- [ ] Execute vulnerability scan script `./scripts/scan-all.sh` → Zero HIGH/CRITICAL unpatched vulnerabilities → AC-5

## Functional End-to-End Flow
- [ ] Test Auth registration (`POST /api/auth/register`) → returns 201 with JWT token → AC-6
- [ ] Test Auth token verification (`GET /api/auth/verify`) → returns valid: true with claims → AC-6
- [ ] Test Task creation (`POST /api/tasks`) → dispatches to Celery worker via Redis, returns 202 → AC-6
- [ ] Test Celery background task processing → task status transitions from PENDING to SUCCESS → AC-6
- [ ] Access React frontend at `http://localhost:8080/` → UI renders, shows real-time health badges and tasks → AC-6

## Production Hardening Checks
- [ ] Verify `docker-compose.prod.yml` configuration: CPU/memory limits, read-only root filesystems, docker secrets → AC-4

## Acceptance-criteria coverage
- AC-1 (Production Dockerfiles, multi-stage, minimized context) covered by Build checks
- AC-2 (Non-root user execution UID 10001 / 10002 / node) covered by User inspection check
- AC-3 (Deterministic health checks and readiness dependencies) covered by Compose startup check
- AC-4 (Production resource limits and read-only filesystems) covered by Compose prod check
- AC-5 (Trivy vulnerability scan and ACR tagging) covered by scan script check
- AC-6 (Full end-to-end user auth and async worker task execution) covered by functional flow check
