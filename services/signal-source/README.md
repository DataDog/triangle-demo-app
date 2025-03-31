# Triangle Signal Source Service

A Rust-based service that generates and manages signal sources for the triangulation system. This service simulates signal sources, manages their lifecycle, and coordinates with the simulation service for signal processing.

## Features

- Real-time signal source generation and management
- Background signal loop for continuous operation
- MongoDB integration for signal persistence
- RESTful API endpoints for signal management
- Health monitoring and status checks
- CORS support for cross-origin requests

## Tech Stack

- Rust 2021 edition
- Actix-web for the web framework
- MongoDB for data persistence
- Tokio for async runtime
- Reqwest for HTTP client
- Serde for serialization/deserialization

## API Endpoints

- `GET /signals` - Retrieve current signal information
- `GET /healthz` - Health check endpoint

## Project Structure

```
src/
├── main.rs          # Application entry point and server setup
├── signal.rs        # Signal-related types and handlers
├── signal_loop.rs   # Background signal generation loop
├── mongo.rs         # MongoDB connection and utilities
└── health.rs        # Health check implementation
```
