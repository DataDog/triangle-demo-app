#!/bin/bash
set -e

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

echo "📄 Loading environment variables from .env"
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "❌ .env file not found!"
  exit 1
fi

echo "🐳 Building Docker images..."
docker build -t signal-source:local ./services/signal-source
docker build -t simulation:local ./services/simulation
docker build -t locator:local ./services/locator

echo "📦 Deploying Helm charts..."
helm upgrade --install mongodb ./charts/mongodb \
  --set-string username=$MONGO_USERNAME \
  --set-string password=$MONGO_PASSWORD \
  --set-string database=$MONGO_DB

helm upgrade --install simulation ./charts/simulation
helm upgrade --install signal-source ./charts/signal-source
helm upgrade --install locator ./charts/locator

echo "✅ All services deployed."
