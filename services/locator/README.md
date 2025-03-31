# Triangle Locator Service

A Go-based service that handles signal triangulation and location detection. This service processes signal bundles from multiple towers and calculates the precise location of signal sources using advanced triangulation algorithms.

## Features

- Real-time signal triangulation and location detection
- Advanced mathematical algorithms for precise positioning
- MongoDB integration for detection persistence
- RESTful API endpoints for bundle processing and detection retrieval
- Health monitoring and status checks
- Efficient processing of multiple signal sources

## Tech Stack

- Go 1.21.5
- Gin for the web framework
- MongoDB for data persistence
- Gonum for numerical computing and triangulation algorithms
- Standard Go concurrency patterns

## API Endpoints

- `POST /bundle` - Process a new signal bundle for triangulation
- `GET /api/locator/detections` - Retrieve current detection information
- `GET /healthz` - Health check endpoint

## Project Structure

```
.
├── main.go           # Application entry point and server setup
├── handlers/         # HTTP request handlers
│   ├── bundle.go     # Signal bundle processing
│   └── detections.go # Detection retrieval
├── logic/           # Core business logic
│   └── triangulate.go # Triangulation algorithms
├── models/          # Data models and types
└── mongo/           # Database connection and utilities
```
