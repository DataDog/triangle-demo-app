#!/bin/bash
set -e

DOCKER_PRUNE=false

# Parse command-line flags
while getopts "d" opt; do
  case $opt in
    d)
      DOCKER_PRUNE=true
      ;;
    *)
      echo "Usage: $0 [-d]"
      echo "  -d    Also prune unused Docker images/volumes"
      exit 1
      ;;
  esac
done

echo "🧼 Cleaning up..."

# Delete Helm releases
echo "🧹 Deleting Helm release: signal-source"
helm uninstall signal-source || true

echo "🧹 Deleting Helm release: simulation"
helm uninstall simulation || true

echo "🧹 Deleting Helm release: mongodb"
helm uninstall mongodb || true

# Remove Docker images
echo "🧹 Removing Docker image: signal-source:local"
docker rmi signal-source:local || true

echo "🧹 Removing Docker image: simulation:local"
docker rmi simulation:local || true

# Optionally prune unused Docker stuff
if [ "$DOCKER_PRUNE" = true ]; then
  echo "🗑  Pruning unused Docker images/containers/volumes..."
  docker system prune -f
fi

echo "✅ Cleanup complete."
