#!/bin/bash

# Load configuration
source ./scripts/lib.sh
load_config

# Cleanup Kubernetes resources
cleanup_k8s() {
    local namespace=$1
    echo "🧹 Cleaning up Kubernetes resources in namespace $namespace..."

    # Delete Helm releases
    helm uninstall world-simulator -n $namespace || true
    helm uninstall base-tower -n $namespace || true

    # Delete Ingress
    kubectl delete -f k8s/ingress.yaml -n $namespace || true

    # Delete all resources in namespace
    kubectl delete all --all -n $namespace || true

    # Delete namespace if it exists
    if kubectl get namespace $namespace >/dev/null 2>&1; then
        kubectl delete namespace $namespace
    fi
}

# Cleanup Docker images
cleanup_docker() {
    echo "🧹 Cleaning up Docker images..."
    eval $(minikube docker-env)
    docker rmi world-simulator base-tower-service || true
}

# Main cleanup
cleanup_k8s $namespace
cleanup_docker

echo "✅ Cleanup complete."
