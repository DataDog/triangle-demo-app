#!/bin/bash
set -e

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

echo "📄 Loading environment variables from .env"
set -o allexport
source .env
set +o allexport

echo "🐳 Building Docker images..."
docker build -t simulation:local ./services/simulation
docker build -t signal-source:local ./services/signal-source
docker build -t locator:local ./services/locator
docker build -t frontend:local ./services/frontend \
  --build-arg VITE_SIMULATION_BASE=/api/simulation \
  --build-arg VITE_SIGNAL_SOURCE_BASE=/api/signals \
  --build-arg VITE_LOCATOR_BASE=/api/locator

echo "📦 Deploying Helm charts..."
helm upgrade --install mongodb ./charts/mongodb \
  --set-string username=$MONGO_USERNAME \
  --set-string password=$MONGO_PASSWORD \
  --set-string database=$MONGO_DB

# Create Datadog secret
echo "🔑 Creating Datadog secret..."
kubectl create secret generic datadog-secret \
  --from-literal=DD_API_KEY=$DD_API_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy OpenTelemetry collector first since other services might need it
echo "📊 Deploying OpenTelemetry collector..."
helm upgrade --install otel ./charts/otel \
  --set-string DD_API_KEY=$DD_API_KEY \
  --set-string DD_SITE=$DD_SITE

helm upgrade --install simulation ./charts/simulation
helm upgrade --install signal-source ./charts/signal-source
helm upgrade --install locator ./charts/locator
helm upgrade --install frontend ./charts/frontend

echo "🌐 Applying Ingress..."
kubectl apply -f charts/shared/templates/ingress.yaml

echo "🌍 Use this to access the app:"
minikube service ingress-nginx-controller -n ingress-nginx --url
