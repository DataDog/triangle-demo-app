#!/bin/bash
set -e

echo "🧹 Cleaning up Kubernetes resources..."

# Kill any port forwarding processes
echo "🛑 Stopping port forwarding..."
pkill -f "kubectl port-forward" || true

# Delete cluster-scoped resources first
echo "🗑️  Removing cluster-scoped resources..."
kubectl delete clusterrole otel-collector --ignore-not-found
kubectl delete clusterrolebinding otel-collector --ignore-not-found

# Delete Helm releases
echo "🗑️  Removing Helm releases..."
helm uninstall frontend -n ${KUBERNETES_NAMESPACE:-default} || true
helm uninstall simulation -n ${KUBERNETES_NAMESPACE:-default} || true
helm uninstall signal-source -n ${KUBERNETES_NAMESPACE:-default} || true
helm uninstall locator -n ${KUBERNETES_NAMESPACE:-default} || true
helm uninstall mongodb -n ${KUBERNETES_NAMESPACE:-default} || true
helm uninstall otel -n ${KUBERNETES_NAMESPACE:-default} || true

# Delete deployments, services, and ingress
echo "🗑️  Removing deployments, services, and ingress..."
kubectl delete deployment --all -n ${KUBERNETES_NAMESPACE:-default} --ignore-not-found
kubectl delete svc --all -n ${KUBERNETES_NAMESPACE:-default} --ignore-not-found
kubectl delete ingress --all -n ${KUBERNETES_NAMESPACE:-default} --ignore-not-found
kubectl delete secret --all -n ${KUBERNETES_NAMESPACE:-default} --ignore-not-found

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

# Remove Docker images
for img in signal-source simulation locator frontend; do
  echo "🧹 Removing Docker image: $img:local"
  docker rmi "$img:local" || true
done

echo "✅ Cleanup complete."
