#!/bin/bash
set -e

echo "🧹 Cleaning up previous deployments..."
kubectl delete deployment --all -n ${KUBERNETES_NAMESPACE:-default}
kubectl delete svc --all -n ${KUBERNETES_NAMESPACE:-default}
kubectl delete ingress --all -n ${KUBERNETES_NAMESPACE:-default}

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

echo "📄 Loading environment variables from .env"
set -o allexport
source .env
set +o allexport

# Check required environment variables
required_vars=("MONGO_USERNAME" "MONGO_PASSWORD" "MONGO_DB" "DD_API_KEY" "DD_SITE")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required environment variable $var is not set"
        exit 1
    fi
done

# Enable ingress-nginx
echo "🔄 Enabling ingress-nginx..."
minikube addons enable ingress

echo "🐳 Building Docker images..."
docker build -t simulation:local ./services/simulation
docker build -t signal-source:local ./services/signal-source
docker build -t locator:local ./services/locator
docker build -t frontend:local ./services/frontend

echo "📦 Deploying Helm charts..."

# Common Helm values for all charts
HELM_GLOBAL_VALUES="--set global.namespace=${KUBERNETES_NAMESPACE:-default} \
  --set mongodb.auth.username=$MONGO_USERNAME \
  --set mongodb.auth.password=$MONGO_PASSWORD \
  --set mongodb.auth.database=$MONGO_DB \
  --set global.datadog.apiKey=$DD_API_KEY \
  --set global.datadog.site=$DD_SITE"

# Deploy MongoDB
echo "🚀 Deploying MongoDB..."
helm upgrade --install mongodb ./charts/mongodb \
  --namespace ${KUBERNETES_NAMESPACE:-default} \
  --set-string mongodb.auth.username=$MONGO_USERNAME \
  --set-string mongodb.auth.password=$MONGO_PASSWORD \
  --set-string mongodb.auth.database=$MONGO_DB

# Create Datadog secret
echo "🔑 Creating Datadog secret..."
kubectl create secret generic datadog-secret \
  --namespace ${KUBERNETES_NAMESPACE:-default} \
  --from-literal=DD_API_KEY=$DD_API_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy OpenTelemetry Collector
echo "🚀 Deploying OpenTelemetry Collector..."
# First, delete any existing cluster-scoped resources
kubectl delete clusterrole otel-collector --ignore-not-found
kubectl delete clusterrolebinding otel-collector --ignore-not-found

# Then deploy the collector
helm upgrade --install otel ./charts/otel \
    --namespace ${KUBERNETES_NAMESPACE:-default} \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

# Deploy services
echo "🚀 Deploying services..."
helm upgrade --install simulation ./charts/simulation \
    --namespace ${KUBERNETES_NAMESPACE:-default} \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install signal-source ./charts/signal-source \
    --namespace ${KUBERNETES_NAMESPACE:-default} \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install locator ./charts/locator \
    --namespace ${KUBERNETES_NAMESPACE:-default} \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install frontend ./charts/frontend \
    --namespace ${KUBERNETES_NAMESPACE:-default} \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n ${KUBERNETES_NAMESPACE:-default}
kubectl wait --for=condition=available --timeout=300s deployment/simulation -n ${KUBERNETES_NAMESPACE:-default}
kubectl wait --for=condition=available --timeout=300s deployment/signal-source -n ${KUBERNETES_NAMESPACE:-default}
kubectl wait --for=condition=available --timeout=300s deployment/locator -n ${KUBERNETES_NAMESPACE:-default}

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=frontend -n ${KUBERNETES_NAMESPACE:-default} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=simulation -n ${KUBERNETES_NAMESPACE:-default} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=signal-source -n ${KUBERNETES_NAMESPACE:-default} --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=locator -n ${KUBERNETES_NAMESPACE:-default} --timeout=300s

echo "🌐 Applying Ingress..."
# Process the ingress template with helm and apply it
helm template ingress ./charts/shared \
  --namespace ${KUBERNETES_NAMESPACE:-default} \
  -f ./charts/shared/values.yaml \
  --set global.namespace=${KUBERNETES_NAMESPACE:-default} \
  --show-only templates/ingress.yaml | kubectl apply -f -

# Function to clean up port forwarding on script exit
cleanup() {
    echo "🧹 Cleaning up port forwarding..."
    kill $(jobs -p) 2>/dev/null
    exit 0
}

# Set up trap for cleanup on script termination
trap cleanup SIGINT SIGTERM

echo "🌍 Setting up port forwarding..."
echo "Access the application at http://localhost:8080"
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &

# Keep the script running to maintain port forwarding
echo "🔄 Services are running. Press Ctrl+C to stop..."
wait
