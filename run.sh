#!/bin/bash

# Unified runner for dev, prod, reload, and teardown workflows
# Usage:
#   ./run.sh dev      → Start Vite with hot reload
#   ./run.sh prod     → Build, dockerize, and deploy to Minikube
#   ./run.sh reload   → Rebuild image and rollout restart (no reapply)
#   ./run.sh down     → Tear down all resources and cleanup

MODE=$1
NAMESPACE=triangle

if [[ "$MODE" == "dev" ]]; then
  echo "🔧 Starting development server..."
  pushd services/world-simulator || exit 1
  npm install
  npm run dev
  popd

elif [[ "$MODE" == "prod" ]]; then
  echo "🚀 Building for production and deploying to Minikube..."
  pushd services/world-simulator || exit 1
  npm install
  npm run build
  eval $(minikube docker-env)
  docker build -t world-simulator .
  popd

  # Ensure namespace exists
  kubectl get namespace $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

  echo "📦 Applying Kubernetes manifests..."
  kubectl apply -k k8s/ -n $NAMESPACE

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

elif [[ "$MODE" == "down" ]]; then
  echo "🧹 Tearing down Kubernetes resources and image..."
  if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    kubectl delete all --all -n $NAMESPACE
    kubectl delete namespace $NAMESPACE
  else
    echo "ℹ️ Namespace $NAMESPACE does not exist. Skipping K8s cleanup."
  fi
  eval $(minikube docker-env)
  docker rmi world-simulator || true
  echo "✅ Teardown complete."

else
  echo "❌ Unknown mode. Use: dev, prod, reload, or down"
  exit 1
fi
