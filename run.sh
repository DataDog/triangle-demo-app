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

echo "🐳 Building signal-source image"
docker build -t signal-source:local ./services/signal-source

echo "📳 Building simulation image"
docker build -t simulation:local ./services/simulation

echo "📦 Deploying MongoDB chart"
helm upgrade --install mongodb ./charts/mongodb \
  --set-string username=$MONGO_USERNAME \
  --set-string password=$MONGO_PASSWORD \
  --set-string database=$MONGO_DB

echo "📦 Deploying Signal Source chart"
helm upgrade --install signal-source ./charts/signal-source

echo "📦 Deploying Simulation chart"
helm upgrade --install simulation ./charts/simulation

echo "✅ All services deployed."
