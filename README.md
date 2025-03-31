# Triangle Signal Triangulation System

A distributed system for real-time signal triangulation and location detection, built with modern microservices architecture.

## Overview

Triangle is a system that simulates, processes, and visualizes signal triangulation in real-time. It consists of multiple microservices working together to:
1. Generate simulated signal sources
2. Process signals through multiple towers
3. Calculate precise locations using triangulation
4. Visualize the entire process in real-time

## Architecture

The system consists of the following services:

### Signal Source Service (Rust)
- Generates simulated signal sources
- Manages signal lifecycle
- Coordinates with simulation service
- Built with Rust and Actix-web

### Simulation Service (Python)
- Manages signal triangulation simulation
- Handles tower management
- Processes incoming signals
- Built with FastAPI and MongoDB

### Locator Service (Go)
- Performs precise triangulation calculations
- Processes signal bundles from multiple towers
- Calculates source locations
- Built with Go and Gin

### Frontend Service (React)
- Real-time visualization of signals and detections
- Interactive map interface
- Smooth animations and transitions
- Built with React, TypeScript, and Konva.js

Each service also has their own README.

## Prerequisites

- Docker and Docker Compose
- Minikube
- kubectl
- Helm
- Node.js (for local frontend development)
- Go 1.21.5+ (for local locator development)
- Python 3.8+ (for local simulation development)
- Rust (for local signal-source development)

## Quick Start

1. Clone the repository:
```bash
git clone <repository-url>
cd triangle
```

2. Create a `.env` file with required environment variables:
```bash
# MongoDB Configuration
MONGO_USERNAME=your_username
MONGO_PASSWORD=your_password
MONGO_DB=triangle

# Service URLs and API Bases
SIMULATION_URL=http://simulation:8000/signal
VITE_SIMULATION_BASE=/api/simulation
VITE_SIGNAL_SOURCE_BASE=/api/signals
VITE_LOCATOR_BASE=/api/locator
```

3. Start the application:
```bash
./run.sh
```

4. Access the application:
```bash
minikube service ingress-nginx-controller -n ingress-nginx --url
```

### Kubernetes Deployment

The application is designed to run on Kubernetes using Helm charts:

```
charts/
├── frontend/        # Frontend service deployment
├── locator/         # Locator service deployment
├── mongodb/         # MongoDB deployment
├── shared/          # Shared Kubernetes resources
├── signal-source/   # Signal source service deployment
└── simulation/      # Simulation service deployment
```

## Cleanup

To clean up the deployment:

```bash
./cleanup.sh
```

Use `./cleanup.sh -d` to also prune unused Docker resources.

## Project Structure

```
.
├── charts/          # Kubernetes Helm charts
├── services/        # Microservices
│   ├── frontend/    # React frontend
│   ├── locator/     # Go triangulation service
│   ├── simulation/  # Python simulation service
│   └── signal-source/ # Rust signal generation
├── run.sh          # Deployment script
└── cleanup.sh      # Cleanup script
```
