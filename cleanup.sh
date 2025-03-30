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
for svc in signal-source simulation locator mongodb; do
  echo "🧹 Deleting Helm release: $svc"
  helm uninstall "$svc" || true
done

# Remove Docker images
for img in signal-source simulation locator; do
  echo "🧹 Removing Docker image: $img:local"
  docker rmi "$img:local" || true
done

# Optionally prune Docker system
if [ "$DOCKER_PRUNE" = true ]; then
  echo "🗑  Pruning unused Docker resources..."
  docker system prune -f
fi

echo "✅ Cleanup complete."
