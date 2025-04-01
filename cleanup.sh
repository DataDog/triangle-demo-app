#!/bin/bash
set -e

echo "🧹 Cleaning up previous deployments..."
kubectl delete deployment --all
kubectl delete svc --all
kubectl delete ingress --all

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

# Remove Docker images
for img in signal-source simulation locator frontend; do
  echo "🧹 Removing Docker image: $img:local"
  docker rmi "$img:local" || true
done

echo "✅ Cleanup complete."
