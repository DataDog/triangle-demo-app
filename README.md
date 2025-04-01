# Triangle Signal Triangulation System

This is a demo app, not meant to be used in production.

A distributed system for real-time signal triangulation and location detection, built with modern microservices architecture. 

## Overview

Triangle is a system that simulates, processes, and visualizes signal triangulation in real-time.

A Rust source service simulates sending a loud sound to a simulator.

The Python simulator service receives the sound, and simulates the sound wave reaching several sensor towers. Each tower will "hear" the sound at different times due to the speed of sound.

The simulator service sends the tower locations and the time that each tower heard the sound to the locator service.

The Go locator service uses complex equation systems to "triangulate" the source of the sound. This is calculated based on the differences in sound arrival time and tower locations. This requires very complex math and is useful for things like traces and spans.

Each service also interacts with a MongoDB database.

The source service stores the source signal locations and times.

The simulator service stores the tower locations

The locator service stores its estimated source location



The frontend reads all these values and displays them on a simple grid. Source signals send out a wave and the towers "triangulate" and plot an estimated source. The system is so accurate that can be hard to tell that it is an estimation.

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

## Third-Party Components

This project uses various open-source components. A complete list of third-party components, their origins, licenses, and copyright information can be found in [LICENSE-3rdparty.csv](LICENSE-3rdparty.csv).

### Component Owners

The following team members are responsible for tracking and updating third-party components:

- Frontend Components: [Frontend Team Member]
- Python Components: [Python Team Member]
- Go Components: [Go Team Member]
- Rust Components: [Rust Team Member]

### License Compliance

All third-party components used in this project are licensed under permissive open-source licenses (MIT, Apache-2.0, BSD-3-Clause) that are compatible with our proprietary license.

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

Note: The first time running this will take time, future runs are much faster (< 1 minute).

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

## Contributing

1. Create a new branch for your feature
2. Make your changes
3. Submit a pull request

## License

This project is proprietary and confidential. See [LICENSE](LICENSE) for details.

## Third-Party Licenses

This project includes third-party open-source components. See [LICENSE-3rdparty.csv](LICENSE-3rdparty.csv) for a complete list of components and their licenses.
