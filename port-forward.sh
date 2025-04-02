#!/bin/bash
set -e

echo "🌍 Setting up port forwarding..."

# Function to clean up port forwarding on script exit
cleanup() {
    echo "🧹 Cleaning up port forwarding..."
    kill $(jobs -p) 2>/dev/null
    exit 0
}

# Set up trap for cleanup on script termination
trap cleanup SIGINT SIGTERM

# Port forward for ingress-nginx
echo "📡 Forwarding ingress-nginx to port 8080..."
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &

# Port forward for MongoDB (optional, for debugging)
echo "📡 Forwarding MongoDB to port 27017..."
kubectl port-forward -n ${KUBERNETES_NAMESPACE:-default} service/mongodb 27017:27017 &

# Port forward for OpenTelemetry Collector (optional, for debugging)
echo "📡 Forwarding OpenTelemetry Collector to port 4317..."
kubectl port-forward -n ${KUBERNETES_NAMESPACE:-default} service/otel-collector 4317:4317 &

echo "✅ Port forwarding is active."
echo "Access the application at http://localhost:8080"
echo "Press Ctrl+C to stop port forwarding..."
echo ""
echo "Port forwarding is running in the background..."
echo "This terminal will stay open to maintain the connections."
echo "To stop port forwarding, press Ctrl+C in this terminal."

# Keep the script running to maintain port forwarding
wait
