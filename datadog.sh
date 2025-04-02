#!/bin/bash
set -e

echo "📄 Loading environment variables from .env"
set -o allexport
source .env
set +o allexport

