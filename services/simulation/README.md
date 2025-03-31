# Triangle Simulation Service

A FastAPI-based service that simulates signal triangulation and detection in real-time. This service manages signal sources, towers, and processes signal detections for triangulation.

## Features

- Real-time signal processing and triangulation
- Tower management and initialization
- MongoDB integration for data persistence
- RESTful API endpoints for signal and tower management
- Health monitoring and status checks

## Tech Stack

- Python 3.8+
- FastAPI for the web framework
- Motor for async MongoDB operations
- Uvicorn for ASGI server
- HTTPX for async HTTP client

## API Endpoints

- `POST /signal` - Receive and process new signals
- `GET /api/simulation/towers` - Retrieve all tower information
- `GET /healthz` - Health check endpoint

## Project Structure

```
app/
├── main.py           # FastAPI application and route definitions
├── simulation.py     # Simulation logic and tower initialization
├── signal_processor.py  # Signal processing and triangulation
├── models.py         # Data models and schemas
└── db.py            # Database connection and utilities
```
