#!/bin/bash
set -e

DOCKER_PRUNE=false

while getopts "d" opt; do
  case $opt in
    d) DOCKER_PRUNE=true ;;
    *)
      echo "Usage: $0 [-d]"
      echo "  -d    Also prune unused Docker images/volumes"
      exit 1 ;;
  esac
done

echo "🧼 Cleaning up..."

# Delete Helm releases
for svc in signal-source simulation locator frontend mongodb otel; do
  echo "🧹 Deleting Helm release: $svc"
  helm uninstall "$svc" || true
done

# Clean up ConfigMaps and Secrets
echo "🧹 Cleaning up OpenTelemetry ConfigMaps and Secrets..."
kubectl delete configmap datadog-config otel-collector-config --ignore-not-found || true
kubectl delete secret datadog-secret --ignore-not-found || true

# Clean up OpenTelemetry resources
echo "🧹 Cleaning up OpenTelemetry resources..."
kubectl delete service otel-collector --ignore-not-found || true
kubectl delete deployment otel-collector --ignore-not-found || true
kubectl delete serviceaccount otel-collector --ignore-not-found || true
kubectl delete clusterrole otel-collector --ignore-not-found || true
kubectl delete clusterrolebinding otel-collector --ignore-not-found || true

# Force delete pods
echo "🧹 Force deleting any remaining OpenTelemetry pods..."
kubectl delete pod -l app=otel-collector --force --grace-period=0 --ignore-not-found || true

# Wait for deletion
echo "⏳ Waiting for resources to be fully deleted..."
sleep 5

# Wait for specific resources to terminate
wait_for_termination() {
  local type=$1
  local label_or_name=$2
  local timeout=30

  while kubectl get "$type" $label_or_name --ignore-not-found | grep -q 'otel-collector'; do
    sleep 1
    timeout=$((timeout - 1))
    if [ "$timeout" -eq 0 ]; then
      echo "❌ Timeout waiting for $type $label_or_name to be deleted"
      exit 1
    fi
  done
}

# Force deletion with verification
if kubectl get service otel-collector --ignore-not-found | grep -q 'otel-collector'; then
  echo "⚠️  Service still exists, forcing deletion..."
  kubectl delete service otel-collector --force --grace-period=0 --ignore-not-found
  echo "⏳ Waiting for service to be fully terminated..."
  wait_for_termination service otel-collector
fi

if kubectl get deployment otel-collector --ignore-not-found | grep -q 'otel-collector'; then
  echo "⚠️  Deployment still exists, forcing deletion..."
  kubectl delete deployment otel-collector --force --grace-period=0 --ignore-not-found
  echo "⏳ Waiting for deployment to be fully terminated..."
  wait_for_termination deployment otel-collector
fi

if kubectl get pods -l app=otel-collector --ignore-not-found | grep -q 'otel-collector'; then
  echo "⚠️  Pods still exist, forcing deletion..."
  kubectl delete pods -l app=otel-collector --force --grace-period=0 --ignore-not-found
  echo "⏳ Waiting for pods to be fully terminated..."
  wait_for_termination pods "-l app=otel-collector"
fi

# Final verification
echo "🔍 Final verification of cleanup..."
if kubectl get service otel-collector --ignore-not-found | grep -q 'otel-collector' || \
   kubectl get deployment otel-collector --ignore-not-found | grep -q 'otel-collector' || \
   kubectl get pods -l app=otel-collector --ignore-not-found | grep -q 'otel-collector'; then
  echo "❌ Some resources still exist after cleanup. Please check manually."
  exit 1
fi

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

# Remove Docker images
for img in signal-source simulation locator frontend; do
  echo "🧹 Removing Docker image: $img:local"
  docker rmi "$img:local" || true
done

if [ "$DOCKER_PRUNE" = true ]; then
  echo "🗑  Pruning unused Docker resources..."
  docker system prune -f
fi

echo "🧼 Cleaning up port forwards..."

for svc in frontend simulation signal-source locator; do
  pidfile=".pf-${svc}.pid"
  logfile=".pf-${svc}.log"
  if [ -f "$pidfile" ]; then
    echo "🛑 Killing port-forward for $svc..."
    kill $(cat "$pidfile") || true
    rm "$pidfile" "$logfile" || true
  fi
done

echo "✅ Cleanup complete."
