# Docker Containerization & Microservices Optimization Stack

Production-ready multi-service containerized architecture demonstrating Docker image optimization, layer caching, security hardening, non-root execution, Trivy vulnerability scanning, and Docker Compose orchestration.

---

## 1. Architecture Overview

```text
                           Client / Browser
                                 │
                            NGINX (Port 80)
                                 │
                         React Frontend (Vite)
                                 │
                         Flask Backend API (:5000)
                        /        │        \
                       /         │         \
     Auth Service (:4000)   PostgreSQL (:5432)   Redis (:6379)
     (Node.js / Express)                             │
                                              Celery Worker
```

### Services Matrix

| Service | Stack / Base | Runtime User | Multi-Stage | Port | Health Check |
|---|---|---|:---:|---|---|
| **frontend** | Node 20 Alpine -> NGINX Alpine | `nginx` (101) | Yes (2-stage) | `80:80` | `curl -f http://localhost/` |
| **backend** | Python 3.11 Slim | `appuser` (10001) | Yes (Wheels builder) | `5000:5000` | `python /app/healthcheck.py` |
| **auth-service** | Node 20 Alpine | `node` (1000) | Yes (Deps + Build) | `4000:4000` | `node /app/healthcheck.js` |
| **worker** | Python 3.11 Slim (Celery) | `appuser` (10001) | Yes (Wheels builder) | — | `celery inspect ping` |
| **postgres** | PostgreSQL 15 Alpine | `postgres` | Official Alpine | `5432` | `pg_isready` |
| **redis** | Redis 7 Alpine | `redis` | Official Alpine | `6379` | `redis-cli ping` |

---

## 2. Security & Optimization Highlights

- **Multi-Stage Builds**: Build toolchains (`gcc`, `python-dev`, Node compiler) excluded from final runtime containers.
- **Minimal Base Images**: Alpine and Debian-slim runtime layers minimize attack surface and CVE count.
- **Non-Root Execution**: Every custom service runs under unprivileged users (`appuser:10001`, `node:1000`, `nginx:101`).
- **Read-Only Root Filesystems**: Containers run `--read-only` with `tmpfs` mounts for `/tmp` and `/run` in production compose.
- **No Hardcoded Secrets**: Secrets injected via Docker Secrets (`/run/secrets/*`) or environment variables.
- **Optimized Layer Caching**: Dependency manifests (`package*.json`, `requirements.txt`) copied before application source.
- **Resource Constraints**: CPU and memory limits defined across all services (`docker-compose.prod.yml`).
- **Security Vulnerability Gates**: Trivy scanning integrated (`scripts/scan-all.sh` & GitHub Actions CI).

---

## 3. Directory Layout

```text
.
├── frontend/                 # React Vite frontend + NGINX reverse proxy & multi-stage Dockerfile
├── backend/                  # Flask REST API + Gunicorn + multi-stage Dockerfile
├── auth-service/             # Express.js Auth Microservice + JWT + multi-stage Dockerfile
├── worker/                   # Celery background worker + Redis broker
├── docker-compose.yml        # Development compose stack with live mounts
├── docker-compose.prod.yml   # Production hardened compose stack (security limits, read-only, secrets)
├── scripts/
│   ├── build-all.sh          # Parallel BuildKit image compilation script
│   ├── scan-all.sh           # Automated Trivy vulnerability scanner
│   ├── push-all.sh           # Tag and push images to container registry (e.g., Azure Container Registry)
│   └── benchmark.sh          # Container size, startup, and memory benchmark utility
├── secrets/                  # Production Docker Secrets configuration
└── .github/workflows/        # Automated security scanning and build pipeline
```

---

## 4. Quickstart

### Prerequisites
- Docker Engine 20.10+
- Docker Compose v2.0+

### Local Development

1. **Start all services**:
   ```bash
   docker compose up --build -d
   ```

2. **Verify container status and health**:
   ```bash
   docker compose ps
   ```

3. **Access endpoints**:
   - Frontend: `http://localhost`
   - Backend API: `http://localhost:5000` (Health: `http://localhost:5000/health`)
   - Auth Service: `http://localhost:4000` (Health: `http://localhost:4000/health`)

4. **Stop environment**:
   ```bash
   docker compose down -v
   ```

---

## 5. Production Hardening Stack

To run with strict resource limits, non-root enforcement, and read-only filesystems:

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

---

## 6. Scripts & Tooling

- **Build all optimized images**:
  ```bash
  ./scripts/build-all.sh
  ```

- **Run security scan with Trivy**:
  ```bash
  ./scripts/scan-all.sh
  ```

- **Run image benchmark & resource measurement**:
  ```bash
  ./scripts/benchmark.sh
  ```

- **Push to registry (ACR / DockerHub)**:
  ```bash
  REGISTRY="myregistry.azurecr.io" TAG="v1.0.0" ./scripts/push-all.sh
  ```

---

## 7. Optimization Benchmark

| Metric | Unoptimized Baseline | Optimized Multi-Stage | Reduction |
|---|---:|---:|---:|
| **Frontend Image** | ~1.2 GB | ~28 MB | **-97%** |
| **Backend API Image** | ~850 MB | ~145 MB | **-83%** |
| **Auth Service Image** | ~680 MB | ~120 MB | **-82%** |
| **Startup Time** | ~45s | ~8s | **-82%** |
| **Base Memory Footprint** | ~512 MB | ~128 MB | **-75%** |
