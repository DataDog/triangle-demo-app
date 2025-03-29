#!/bin/bash

# Docker operations module
# Handles all Docker-related operations

# Build and push Docker image
build_docker_image() {
    local service=$1
    local tag=$2
    local context=${3:-"services/$service"}

    info "Building Docker image for $service..."
    pushd $context || exit 1

    # Set up Docker environment
    if [ -n "$MINIKUBE_ACTIVE_DOCKERD" ]; then
        eval $(minikube docker-env)
    fi

    # Build image
    docker build -t $service:$tag .

    # Push image if registry is configured
    if [ -n "$DOCKER_REGISTRY" ]; then
        info "Pushing image to registry..."
        docker tag $service:$tag $DOCKER_REGISTRY/$service:$tag
        docker push $DOCKER_REGISTRY/$service:$tag
    fi

    popd
}

# Clean up Docker resources
cleanup_docker() {
    info "Cleaning up Docker resources..."

    # Remove unused images
    docker image prune -f

    # Remove stopped containers
    docker container prune -f

    # Remove unused volumes
    docker volume prune -f
}

# Check Docker daemon
check_docker() {
    info "Checking Docker daemon..."
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        exit 1
    fi
}

# Get Docker image size
get_image_size() {
    local service=$1
    local tag=$2

    docker images $service:$tag --format "{{.Size}}"
}

# List Docker images for service
list_service_images() {
    local service=$1

    docker images $service --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

# Remove Docker image
remove_image() {
    local service=$1
    local tag=$2

    info "Removing Docker image $service:$tag..."
    docker rmi $service:$tag
}
