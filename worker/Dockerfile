# Stage 1: Build virtualenv & dependencies
FROM python:3.11-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
  && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Minimal Runtime
FROM python:3.11-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY tasks.py ./

# Create dedicated non-root user
RUN groupadd -g 10002 celerygroup && \
    useradd -u 10002 -g celerygroup -s /bin/bash -m celeryuser && \
    chown -R celeryuser:celerygroup /app

USER 10002:10002

# Health check verifies Celery worker process is alive and responsive
HEALTHCHECK --interval=20s --timeout=10s --start-period=15s --retries=3 \
  CMD celery -A tasks inspect ping -d celery@$HOSTNAME || exit 1

CMD ["celery", "-A", "tasks", "worker", "--loglevel=info", "-c", "2"]
