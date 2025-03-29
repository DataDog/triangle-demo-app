#!/bin/bash

# Main library file
# Loads all modules and sets up common functionality

# Get absolute path to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$( dirname "${SCRIPT_DIR}" )" && pwd )"
MODULES_DIR="${SCRIPT_DIR}/modules"

# Debug output
echo "Project root: ${PROJECT_ROOT}"
echo "Script directory: ${SCRIPT_DIR}"
echo "Modules directory: ${MODULES_DIR}"

# Function to load a module
load_module() {
    local module=$1
    local module_path="${MODULES_DIR}/${module}.sh"

    if [ -f "${module_path}" ]; then
        echo "Loading module: ${module}"
        source "${module_path}"
    else
        echo "Error: ${module}.sh not found at ${module_path}"
        exit 1
    fi
}

# Load modules
load_module "logging"
load_module "config"
load_module "k8s"
load_module "docker"

# Enhanced error handling
handle_error() {
    local exit_code=$?
    local line_no=$1
    local command=$2

    error "Error on line $line_no: Command '$command' failed with exit code $exit_code"
    cleanup
    exit $exit_code
}

# Set up error handling
set -e
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Main cleanup function
cleanup() {
    info "Running cleanup..."

    # Clean up Kubernetes resources
    if [ -n "$namespace" ]; then
        cleanup_k8s "$namespace"
    fi

    # Clean up Docker resources
    cleanup_docker

    info "Cleanup complete"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    # Check Docker
    check_docker

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi

    # Check helm
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi

    # Check minikube
    if ! command -v minikube &> /dev/null; then
        error "minikube is not installed"
        exit 1
    fi

    info "All prerequisites met"
}

# Load configuration
load_config() {
    if [ ! -f "config.yaml" ]; then
        echo "Error: config.yaml not found"
        exit 1
    fi
    eval $(parse_yaml config.yaml)
}

# Parse YAML file
parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

# Ensure namespace exists
ensure_namespace() {
    local namespace=$1
    echo "📦 Ensuring namespace $namespace exists..."
    kubectl get namespace $namespace >/dev/null 2>&1 || kubectl create namespace $namespace
}

# Build and push Docker image
build_docker_image() {
    local service=$1
    local tag=$2
    local context="${PROJECT_ROOT}/services/${service}"

    info "Building Docker image for $service..."
    if [ ! -d "$context" ]; then
        error "Service directory not found: $context"
        exit 1
    fi

    # Set up Docker environment for Minikube
    eval $(minikube docker-env)

    # Build image with consistent naming
    pushd "$context" || exit 1
    docker build -t "${service}:${tag}" .
    popd

    # Verify image was built
    if ! docker images | grep -q "${service}.*${tag}"; then
        error "Failed to build Docker image: ${service}:${tag}"
        exit 1
    fi

    info "Successfully built Docker image: ${service}:${tag}"
}

# Deploy service using Helm
deploy_helm() {
    local service=$1
    local namespace=$2
    local tag=$3
    echo "🚀 Deploying $service using Helm..."
    helm upgrade --install $service charts/$service -n $namespace --set image.tag=$tag
}

# Apply Kubernetes manifests
apply_k8s() {
    local namespace=$1
    local manifest=$2
    echo "📦 Applying Kubernetes manifest: $manifest..."
    kubectl apply -f $manifest -n $namespace
}

# Wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "⏳ Waiting for $deployment to be ready..."
    kubectl rollout status deployment/$deployment -n $namespace
}

# Health check
health_check() {
    local namespace=$1
    local service=$2
    echo "🔍 Performing health check for $service..."
    kubectl get pods -n $namespace -l app.kubernetes.io/name=$service -o jsonpath='{.items[0].status.phase}' | grep -q "Running"
}
