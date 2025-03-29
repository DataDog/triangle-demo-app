#!/bin/bash
set -e

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

echo "🐳 Building image"
docker build -t signal-source:local ./services/signal-source

echo "📦 Deploying with Helm"
helm upgrade --install signal-source ./charts/signal-source -f ./charts/signal-source/values.yaml
