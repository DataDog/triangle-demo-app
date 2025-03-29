FROM node:18-alpine AS builder
WORKDIR /app
COPY . .

RUN ls -l /app && \
    cat vite.config.js || echo "vite.config.js NOT FOUND"
