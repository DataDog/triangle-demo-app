#!/bin/bash

# Kubernetes operations module
# Handles all Kubernetes-related operations

# Ensure namespace exists
ensure_namespace() {
    local namespace=$1
    info "Ensuring namespace $namespace exists..."
    kubectl get namespace $namespace >/dev/null 2>&1 || kubectl create namespace $namespace
}

# Deploy service using Helm
deploy_helm() {
    local service=$1
    local namespace=$2
    local tag=$3
    info "Deploying $service using Helm..."
    helm upgrade --install $service charts/$service -n $namespace --set image.tag=$tag
}

# Apply Kubernetes manifests
apply_k8s() {
    local namespace=$1
    local manifest=$2
    info "Applying Kubernetes manifest: $manifest..."
    kubectl apply -f $manifest -n $namespace
}

# Wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}  # Default 5 minutes timeout

    info "Waiting for $deployment to be ready..."
    kubectl rollout status deployment/$deployment -n $namespace --timeout=${timeout}s
}

# Health check
health_check() {
    local namespace=$1
    local service=$2
    local timeout=${3:-30}  # Default 30 seconds timeout

    info "Performing health check for $service..."
    local start_time=$(date +%s)

    while true; do
        if kubectl get pods -n $namespace -l app=$service -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
            info "$service is healthy"
            return 0
        fi

        local current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            error "$service health check timed out"
            return 1
        fi

        sleep 2
    done
}

# Monitor resources
monitor_resources() {
    local namespace=$1
    local service=$2

    info "Monitoring resources for $service..."
    kubectl top pods -n $namespace -l app=$service --containers
}

# Get service logs
get_logs() {
    local namespace=$1
    local service=$2
    local lines=${3:-100}  # Default 100 lines

    info "Getting logs for $service..."
    kubectl logs -n $namespace -l app=$service --tail=$lines
}

# Port forward service
port_forward() {
    local namespace=$1
    local service=$2
    local local_port=$3
    local remote_port=$4

    info "Setting up port forward for $service..."
    kubectl port-forward -n $namespace svc/$service $local_port:$remote_port &
    sleep 2  # Give port-forward time to establish
}

# Clean up Kubernetes resources
cleanup_k8s() {
    local namespace=$1

    info "Cleaning up Kubernetes resources in namespace $namespace..."

    # Delete Helm releases
    helm list -n $namespace --short | while read release; do
        helm uninstall $release -n $namespace
    done

    # Delete Ingress resources
    kubectl delete ingress --all -n $namespace --ignore-not-found

    # Delete all resources in namespace
    kubectl delete all --all -n $namespace --ignore-not-found

    # Delete namespace if it exists
    kubectl delete namespace $namespace --ignore-not-found
}
