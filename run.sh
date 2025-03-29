#!/bin/bash

# Load common functions
source ./scripts/lib.sh

# Load configuration
load_config

MODE=$1
NAMESPACE="triangle"

# Utility: styled logging
info() { echo -e "👉 \033[1m$1\033[0m"; }
error() { echo -e "❌ \033[1;31m$1\033[0m"; }

# Ensure required tools
check_requirements() {
  for cmd in helm docker kubectl; do
    if ! command -v $cmd &>/dev/null; then
      error "Missing required command: $cmd"
      exit 1
    fi
  done
}

# Ensure Kubernetes namespace
ensure_namespace() {
  info "Ensuring namespace '$NAMESPACE' exists..."
  kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"
}

# Setup ingress port-forward
setup_port_forward() {
  info "Setting up port-forward for ingress controller..."
  pkill -f "kubectl port-forward.*ingress-nginx-controller" || true
  kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:8080 &
  sleep 2

  if ! curl -s http://localhost:8080 > /dev/null; then
    error "Port-forward may not be working correctly"
  fi
}

# Build Docker image with optional baseTower URL from values.yaml
build_docker_image() {
  local service=$1
  local tag=$2
  local base_tower_url=""

  if [ -f "charts/$service/values.yaml" ]; then
    base_tower_url=$(grep "baseTower:" charts/$service/values.yaml -A 2 | grep "url:" | awk -F': ' '{print $2}' | tr -d '"')
  fi

  info "Building Docker image for $service:$tag"
  if [ -n "$base_tower_url" ]; then
    echo "→ Injecting VITE_BASE_TOWER_URL=$base_tower_url"
    docker build -t "$service:$tag" --build-arg "VITE_BASE_TOWER_URL=$base_tower_url" "services/$service/"
  else
    docker build -t "$service:$tag" "services/$service/"
  fi
}

# Deploy base-tower and world-simulator services
deploy_services() {
  local tag=$1

  build_docker_image "base-tower" "$tag"
  deploy_helm "base-tower" "$NAMESPACE" "$tag"

  build_docker_image "world-simulator" "$tag"
  deploy_helm "world-simulator" "$NAMESPACE" "$tag"

  info "Applying ingress configuration..."
  helm dependency update charts/ingress
  helm upgrade --install triangle-ingress charts/ingress -n "$NAMESPACE"

  wait_for_deployment "$NAMESPACE" "base-tower"
  wait_for_deployment "$NAMESPACE" "world-simulator"

  health_check "$NAMESPACE" "base-tower"
  health_check "$NAMESPACE" "world-simulator"
}

# Modes

dev_mode() {
  info "Starting development mode..."
  ensure_namespace
  deploy_services "dev"
  setup_port_forward
  echo "✅ Dev server running → http://localhost:8080"
}

prod_mode() {
  info "Starting production mode..."
  ensure_namespace
  deploy_services "prod"
  setup_port_forward
  echo "✅ Prod server running → http://localhost:8080"
}

reload_mode() {
  info "Reloading services..."
  deploy_services "dev"
  setup_port_forward
  echo "✅ Reload complete!"
}

down_mode() {
  info "Tearing down services..."
  pkill -f "kubectl port-forward.*ingress-nginx-controller" || true
  for svc in base-tower world-simulator triangle-ingress; do
    helm uninstall "$svc" -n "$NAMESPACE"
  done
  echo "🧹 Cleanup complete."
}

# Entrypoint
check_requirements

case "$MODE" in
  "dev") dev_mode ;;
  "prod") prod_mode ;;
  "reload") reload_mode ;;
  "triangulate") deploy_helm "triangle" "$NAMESPACE" "dev" ;;
  "base") deploy_helm "base-tower" "$NAMESPACE" "dev" ;;
  "db") deploy_helm "postgres" "$NAMESPACE" "dev" ;;
  "down") down_mode ;;
  *)
    error "Usage: $0 {dev|prod|reload|triangulate|base|db|down}"
    exit 1
    ;;
esac
