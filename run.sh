#!/bin/bash
set -e

echo "📄 Loading environment variables from .env"
set -o allexport
source .env
set +o allexport

echo "🧹 Cleaning up previous deployments..."
kubectl delete deployment,svc --all -n $KUBERNETES_NAMESPACE --ignore-not-found
kubectl delete service kubernetes -n $KUBERNETES_NAMESPACE --ignore-not-found
kubectl delete ingress --all -n $KUBERNETES_NAMESPACE --ignore-not-found

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)


# Check required environment variables
required_vars=(
  "MONGO_USERNAME"
  "MONGO_PASSWORD"
  "MONGO_DB"
  "DD_API_KEY"
  "DD_SITE"
  "DD_APP_KEY"
  "DD_CLUSTER_NAME"
  "SIMULATION_URL"
  "VITE_SIMULATION_BASE"
  "VITE_SIGNAL_SOURCE_BASE"
  "VITE_LOCATOR_BASE"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Required environment variable $var is not set"
        exit 1
    fi
done

echo "🔄 Enabling ingress-nginx..."
minikube addons enable ingress

echo "🐕 Setting up Datadog with OpenTelemetry Collector..."
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Install Datadog Operator
echo "🐕 Installing Datadog Operator..."
helm upgrade --install datadog-operator datadog/datadog-operator \
  --namespace $KUBERNETES_NAMESPACE \
  --create-namespace

# Create Datadog secret
echo "🔑 Creating Datadog secret..."
kubectl create secret generic datadog-secret \
  --from-literal=api-key="${DD_API_KEY}" \
  --from-literal=app-key="${DD_APP_KEY}" \
  -n $KUBERNETES_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create OpenTelemetry ConfigMap
echo "📝 Creating OpenTelemetry ConfigMap..."
# Process the YAML file with envsubst
envsubst < charts/datadog/otel-config.yaml > /tmp/otel-config-processed.yaml
# Create the ConfigMap from the processed file
kubectl create configmap otel-agent-config-map \
  --from-file=otel-config.yaml=/tmp/otel-config-processed.yaml \
  -n $KUBERNETES_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
# Clean up the temporary file
rm /tmp/otel-config-processed.yaml

# Process and apply Datadog Agent configuration
echo "🐕 Deploying Datadog Agent with OpenTelemetry Collector..."
envsubst < charts/datadog/templates/datadog-agent.yaml | kubectl apply -f -

echo "🐳 Building Docker images..."
for img in signal-source simulation locator; do
  echo "🔨 Building $img:local"
  docker build -t "$img:local" "services/$img"
done

# Build frontend with build args
echo "🔨 Building frontend:local"
docker build -t frontend:local ./services/frontend \
  --build-arg VITE_SIMULATION_BASE=${VITE_SIMULATION_BASE} \
  --build-arg VITE_SIGNAL_SOURCE_BASE=${VITE_SIGNAL_SOURCE_BASE} \
  --build-arg VITE_LOCATOR_BASE=${VITE_LOCATOR_BASE}

echo "🚀 Deploying services..."
helm upgrade --install mongodb ./charts/mongodb \
  --namespace $KUBERNETES_NAMESPACE \
  --set-string "mongodb.auth.username=${MONGO_USERNAME}" \
  --set-string "mongodb.auth.password=${MONGO_PASSWORD}" \
  --set-string "mongodb.auth.database=${MONGO_DB}"

# Deploy Locator first since other services depend on it
helm upgrade --install locator ./charts/locator \
  --namespace $KUBERNETES_NAMESPACE \
  --set-string "env.MONGO_URI=mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@mongodb:27017/${MONGO_DB}?authSource=admin"

# Deploy Simulation which depends on Locator
helm upgrade --install simulation ./charts/simulation \
  --namespace $KUBERNETES_NAMESPACE \
  --set-string "env.MONGO_USERNAME=${MONGO_USERNAME}" \
  --set-string "env.MONGO_PASSWORD=${MONGO_PASSWORD}" \
  --set-string "env.MONGO_DB=${MONGO_DB}" \
  --set-string "env.LOCATOR_URL=http://locator:8000/bundle"

# Deploy Signal Source which depends on Simulation
helm upgrade --install signal-source ./charts/signal-source \
  --namespace $KUBERNETES_NAMESPACE \
  --set-string "env.MONGO_USERNAME=${MONGO_USERNAME}" \
  --set-string "env.MONGO_PASSWORD=${MONGO_PASSWORD}" \
  --set-string "env.MONGO_DB=${MONGO_DB}" \
  --set-string "env.SIMULATION_URL=${SIMULATION_URL}"

# Deploy Frontend which depends on all services
helm upgrade --install frontend ./charts/frontend \
  --namespace $KUBERNETES_NAMESPACE

helm upgrade --install ingress ./charts/ingress \
  --namespace $KUBERNETES_NAMESPACE

echo "🌍 Use this to access the app:"
minikube service ingress-nginx-controller -n ingress-nginx --url

echo "✅ Deployment complete."
