#!/bin/bash
set -e

echo "📄 Loading environment variables from .env"
set -o allexport
source .env
set +o allexport

echo "🧹 Starting cleanup..."

# Delete Datadog resources first
echo "🗑️  Deleting Datadog resources..."
kubectl delete datadogagent --all -n $KUBERNETES_NAMESPACE --ignore-not-found
kubectl delete crd datadogagents.datadoghq.com --ignore-not-found
kubectl delete clusterrolebinding datadog-agent-clusterrolebinding --ignore-not-found
kubectl delete clusterrole datadog-agent-clusterrole --ignore-not-found

# Delete all Helm releases in the namespace
echo "🗑️  Deleting Helm releases..."
helm list -n $KUBERNETES_NAMESPACE --short | xargs -r helm uninstall -n $KUBERNETES_NAMESPACE || true

# Delete all resources in the namespace
echo "🗑️  Deleting namespace resources..."
kubectl delete all,ingress,secret,configmap --all -n $KUBERNETES_NAMESPACE --ignore-not-found

# Force delete any remaining pods
echo "🗑️  Force deleting any remaining pods..."
kubectl delete pods --all -n $KUBERNETES_NAMESPACE --force --grace-period=0 --ignore-not-found

# Clean up Docker resources
echo "🗑️  Cleaning up Docker resources..."
docker system prune -f

echo "✅ Cleanup complete."
