#!/bin/bash

# Unified runner for dev, prod, reload, triangulate, base, db, and teardown workflows
# Usage:
#   ./run.sh dev         → Start Vite with hot reload and deploy backend services
#   ./run.sh prod        → Build, dockerize, and deploy all services to Minikube
#   ./run.sh reload      → Rebuild image and rollout restart (no reapply)
#   ./run.sh triangulate → Deploy triangle Python service for signal processing
#   ./run.sh base        → Deploy base Go service
#   ./run.sh db          → Deploy PostgreSQL DB
#   ./run.sh down        → Tear down all resources and cleanup

MODE=$1
NAMESPACE=triangle

ensure_namespace() {
  echo "📦 Ensuring namespace $NAMESPACE exists..."
  kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE
}

if [[ "$MODE" == "dev" ]]; then
  ensure_namespace

  echo "🔧 Starting development server..."
  pushd services/world-simulator || exit 1
  npm install
  npm run dev &
  popd

  echo "📡 Building and deploying base Go service..."
  pushd services/base-tower || exit 1
  eval $(minikube docker-env)
  docker build -t base-tower-service .
  popd
  kubectl apply -f k8s/base-tower-service.yaml -n $NAMESPACE

  echo "🐘 Deploying PostgreSQL database..."
  kubectl apply -f k8s/postgres.yaml -n $NAMESPACE

  echo "📦 Deploying triangle processor..."
  kubectl apply -f k8s/triangle-service.yaml -n $NAMESPACE

  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "prod" ]]; then
  ensure_namespace

  echo "🚀 Building for production and deploying all services to Minikube..."
  pushd services/world-simulator || exit 1
  npm install
  npm run build
  eval $(minikube docker-env)
  docker build -t world-simulator .
  popd

  pushd services/base-tower || exit 1
  eval $(minikube docker-env)
  docker build -t base-tower-service .
  popd

  echo "📦 Applying Kubernetes manifests..."
  kubectl apply -k k8s/ -n $NAMESPACE
  kubectl apply -f k8s/base-tower-service.yaml -n $NAMESPACE
  kubectl apply -f k8s/postgres.yaml -n $NAMESPACE
  kubectl apply -f k8s/triangle-service.yaml -n $NAMESPACE

  echo "🌐 Opening app via port-forward..."
  sleep 2
  kubectl port-forward -n $NAMESPACE deployment/world-simulator 8080:8080 &
  echo "Visit http://127.0.0.1:8080"

  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "reload" ]]; then
  echo "🔁 Rebuilding image and restarting deployment..."
  pushd services/world-simulator || exit 1
  npm run build
  eval $(minikube docker-env)
  docker build -t world-simulator .
  popd

  kubectl rollout restart deployment/world-simulator -n $NAMESPACE
  echo "🔄 Rollout triggered. Watching pods..."
  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "triangulate" ]]; then
  ensure_namespace
  echo "📡 Deploying triangle signal processor service..."
  kubectl apply -f k8s/triangle-service.yaml -n $NAMESPACE
  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "base" ]]; then
  ensure_namespace
  echo "📡 Building and deploying base Go service..."
  pushd services/base-tower || exit 1
  eval $(minikube docker-env)
  docker build -t base-tower-service .
  popd

  kubectl apply -f k8s/base-tower-service.yaml -n $NAMESPACE
  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "db" ]]; then
  ensure_namespace
  echo "🐘 Deploying PostgreSQL database..."
  kubectl apply -f k8s/postgres.yaml -n $NAMESPACE
  kubectl get pods -n $NAMESPACE -w

elif [[ "$MODE" == "down" ]]; then
  echo "🧹 Tearing down Kubernetes resources and image..."
  if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    kubectl delete all --all -n $NAMESPACE
    kubectl delete namespace $NAMESPACE
  else
    echo "ℹ️ Namespace $NAMESPACE does not exist. Skipping K8s cleanup."
  fi
  eval $(minikube docker-env)
  docker rmi world-simulator base-tower-service || true
  echo "✅ Teardown complete."

else
  echo "❌ Unknown mode. Use: dev, prod, reload, triangulate, base, db, or down"
  exit 1
fi
