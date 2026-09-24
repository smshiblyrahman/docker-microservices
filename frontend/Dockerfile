# Stage 1: Build React Assets
FROM node:20-alpine AS builder

WORKDIR /app

# Optimize layer caching for dependencies
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Hardened Minimal NGINX unprivileged runtime
FROM nginxinc/nginx-unprivileged:alpine-slim AS runner

# Copy custom NGINX configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled static assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Runs automatically as non-root user 'nginx' (UID 101)
USER 101

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
