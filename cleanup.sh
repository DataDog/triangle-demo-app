#!/bin/bash
set -e

DOCKER_PRUNE=false

while getopts "d" opt; do
  case $opt in
    d) DOCKER_PRUNE=true ;;
    *)
      echo "Usage: $0 [-d]"
      echo "  -d    Also prune unused Docker images/volumes"
      exit 1 ;;
  esac
done

echo "🧼 Cleaning up..."

for svc in signal-source simulation locator frontend mongodb; do
  echo "🧹 Deleting Helm release: $svc"
  helm uninstall "$svc" || true
done

echo "▶️  Using Minikube Docker env"
eval $(minikube docker-env)

for img in signal-source simulation locator frontend; do
  echo "🧹 Removing Docker image: $img:local"
  docker rmi "$img:local" || true
done

if [ "$DOCKER_PRUNE" = true ]; then
  echo "🗑  Pruning unused Docker resources..."
  docker system prune -f
fi

echo "🧼 Cleaning up port forwards..."

for svc in frontend simulation signal-source locator; do
  pidfile=".pf-${svc}.pid"
  logfile=".pf-${svc}.log"
  if [ -f "$pidfile" ]; then
    echo "🛑 Killing port-forward for $svc..."
    kill $(cat "$pidfile") || true
    rm "$pidfile" "$logfile" || true
  fi
done

echo "✅ Cleanup complete."
