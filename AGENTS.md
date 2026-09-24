# Project Guidelines

## Overview
This repository contains a containerized microservices stack optimized for production readiness, local development parity, security, and Kubernetes readiness based on `06-docker-microservices-optimization.md`.

## Tech Stack
- **Frontend**: React (Vite / NGINX alpine runtime multi-stage build)
- **Backend API**: Flask (Python 3.11-slim, Gunicorn, PostgreSQL + Redis integration)
- **Auth Service**: Node.js (Express, JWT tokens, bcrypt, Postgres)
- **Worker**: Celery (Python, Redis broker & result backend)
- **Data Stores**: PostgreSQL 15 Alpine, Redis 7 Alpine
- **Container Orchestration**: Docker Compose (Local Dev) & Docker Compose Prod (Production Hardened)
- **Security & CI**: Trivy container scanning, non-root users, read-only root filesystems, docker secrets, resource limits.

## Rules
- Always use multi-stage builds and minimal runtime images (alpine / slim).
- Always run containers with non-root users (`USER appuser` / `node`).
- Always specify health checks on all long-running services.
- Never hardcode credentials; use environment variables or docker secrets.
- Optimize layer caching by copying dependency manifests before application source code.
