# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app
COPY . .

ARG VITE_SIMULATION_BASE
ARG VITE_SIGNAL_SOURCE_BASE
ARG VITE_LOCATOR_BASE

ENV VITE_SIMULATION_BASE=$VITE_SIMULATION_BASE
ENV VITE_SIGNAL_SOURCE_BASE=$VITE_SIGNAL_SOURCE_BASE
ENV VITE_LOCATOR_BASE=$VITE_LOCATOR_BASE

RUN npm install && npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
WORKDIR /app
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
