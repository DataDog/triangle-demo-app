#!/bin/bash
set -e

# Check for required environment variables
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
  echo "❌ Error: DD_API_KEY and DD_APP_KEY environment variables must be set"
  exit 1
fi

echo "🔄 Adding Datadog Helm repository..."
helm repo add datadog https://helm.datadoghq.com
helm repo update

echo "📦 Installing Datadog Operator..."
helm upgrade --install \
  datadog-operator datadog/datadog-operator \
  --namespace ${KUBERNETES_NAMESPACE:-default} \
  --set image.tag="1.0.2" \
  --create-namespace

echo "⏳ Waiting for Datadog Operator to be ready..."
kubectl wait --for=condition=available deployment/datadog-operator -n ${KUBERNETES_NAMESPACE:-default} --timeout=60s

echo "📦 Installing Datadog Agent with OpenTelemetry Collector..."
helm upgrade --install \
  datadog datadog/datadog \
  --namespace ${KUBERNETES_NAMESPACE:-default} \
  -f charts/datadog-operator/values.yaml \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.appKey=$DD_APP_KEY

echo "✅ Datadog installation complete!"
echo "🔍 You can now view your metrics, traces, and logs in the Datadog dashboard."
