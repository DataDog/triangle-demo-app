#!/bin/bash
set -e

echo "🧹 Cleaning up previous deployments..."
kubectl delete deployment --all
kubectl delete svc --all
kubectl delete ingress --all

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
HELM_GLOBAL_VALUES="--set mongodb.auth.username=$MONGO_USERNAME \
  --set mongodb.auth.password=$MONGO_PASSWORD \
  --set mongodb.auth.database=$MONGO_DB \
  --set global.datadog.apiKey=$DD_API_KEY \
  --set global.datadog.site=$DD_SITE"

# Deploy MongoDB
echo "🚀 Deploying MongoDB..."
helm upgrade --install mongodb ./charts/mongodb \
  --set-string mongodb.auth.username=$MONGO_USERNAME \
  --set-string mongodb.auth.password=$MONGO_PASSWORD \
  --set-string mongodb.auth.database=$MONGO_DB

# Create Datadog secret
echo "🔑 Creating Datadog secret..."
kubectl create secret generic datadog-secret \
  --from-literal=DD_API_KEY=$DD_API_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy OpenTelemetry Collector
echo "🚀 Deploying OpenTelemetry Collector..."
helm upgrade --install otel ./charts/otel \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

# Deploy services
helm upgrade --install simulation ./charts/simulation \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install signal-source ./charts/signal-source \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install locator ./charts/locator \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

helm upgrade --install frontend ./charts/frontend \
    -f ./charts/shared/values.yaml \
    $HELM_GLOBAL_VALUES

echo "🌐 Applying Ingress..."
kubectl apply -f charts/shared/templates/ingress.yaml

echo "🌍 Use this to access the app:"
minikube service ingress-nginx-controller -n ingress-nginx --url

# Keep the script running to maintain services
echo "🔄 Services are running. Press Ctrl+C to stop..."
