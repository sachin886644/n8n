# Stage 1: Build the application
FROM node:22-alpine as builder

# Install system dependencies required for build
RUN apk add --no-cache git findutils

# Install pnpm
RUN npm install -g pnpm@10.22.0

WORKDIR /app

# Copy source code (respecting .dockerignore)
COPY . .

# Install zx explicitly to run the build script
RUN npm install -g zx

# Run the build script
# CI=true prevents some interactive prompts and backup behaviors in the script
ENV CI=true
RUN zx scripts/build-n8n.mjs

# Stage 2: Create the runtime image
# We use n8nio/base as the base image to ensure all system dependencies are present
FROM n8nio/base:22.21.1

ARG N8N_VERSION=snapshot
ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=dev
ENV NODE_ICU_DATA=/usr/local/lib/node_modules/full-icu
ENV SHELL=/bin/sh

WORKDIR /home/node

# Copy the compiled application from the builder stage
COPY --from=builder /app/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

# Install npm with glob fix (matching original Dockerfile)
RUN npm install -g npm@11.6.4

# Setup n8n
RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 && \
    ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

EXPOSE 5678/tcp
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
