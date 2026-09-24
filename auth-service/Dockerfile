# Stage 1: Build & Dependencies
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Install security updates
RUN apk update && apk upgrade --no-cache

# Cache package dependencies
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Minimal Runtime
FROM node:20-alpine AS runner

WORKDIR /usr/src/app

ENV NODE_ENV=production
ENV PORT=5001

# Add curl for health check
RUN apk add --no-cache curl

# Copy production node_modules from builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package.json ./
COPY server.js ./

# Harden runtime: use non-root node user (UID/GID 1000)
USER node

EXPOSE 5001

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5001/health || exit 1

CMD ["node", "server.js"]
