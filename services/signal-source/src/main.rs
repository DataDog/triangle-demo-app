mod mongo;
mod signal;
mod signal_loop;

use std::sync::Arc;
use std::sync::atomic::AtomicBool;

use axum::{
    routing::get,
    Router,
    extract::State,
    response::Json,
};
use opentelemetry::{
    global,
    trace::{SpanKind, Tracer},
};
use opentelemetry_sdk::{propagation::TraceContextPropagator, trace::SdkTracerProvider};
use opentelemetry_stdout::SpanExporter;
use tracing::{info, error};
use tracing_subscriber;
use mongodb::Collection;

use crate::mongo::init_mongo;
use crate::signal_loop::run_signal_loop;
use crate::signal::{Signal, get_signals};

// Initialize tracer
fn init_tracer() -> SdkTracerProvider {
    global::set_text_map_propagator(TraceContextPropagator::new());
    let provider = SdkTracerProvider::builder()
        .with_simple_exporter(SpanExporter::default())
        .build();
    global::set_tracer_provider(provider.clone());
    provider
}

// Simple health check handler
async fn health_check() -> &'static str {
    "OK"
}

// Handler to retrieve signals
async fn get_signals_handler(
    State(signals): State<Arc<Collection<Signal>>>,
) -> Json<Vec<Signal>> {
    let signals_vec = match get_signals(&signals).await {
        Ok(s) => s,
        Err(_) => Vec::new(),
    };
    Json(signals_vec)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    // Set up panic hook
    std::panic::set_hook(Box::new(|panic_info| {
        error!("💥 Panic occurred: {:?}", panic_info);
    }));

    // Initialize tracer
    let _provider = init_tracer();
    info!("Initializing tracer...");
    let tracer = global::tracer("server");
    let _span = tracer
        .span_builder("server_startup")
        .with_kind(SpanKind::Server)
        .start(&tracer);

    info!("Initializing MongoDB connection...");
    let (mongo_client, signals_collection, simulation_url) = match init_mongo().await {
        Ok(result) => {
            info!("✅ MongoDB connection established");
            result
        }
        Err(e) => {
            error!("Failed to initialize MongoDB: {}", e);
            return Ok(());
        }
    };

    // Wrap signals_collection in an Arc for use in both the loop and the router
    let signals_collection_arc = Arc::new(signals_collection);

    // Create a flag to control the signal loop
    let running = Arc::new(AtomicBool::new(true));
    let running_clone = running.clone();

    // Spawn the signal loop in a separate task
    {
        let signals_clone = Arc::clone(&signals_collection_arc);
        let simulation_url_clone = simulation_url.clone();
        tokio::spawn(async move {
            if let Err(e) = run_signal_loop(
                mongo_client,
                signals_clone,
                simulation_url_clone,
                running_clone,
            ).await {
                error!("Signal loop error: {}", e);
            }
        });
    }

    // Build the Axum router
    let app = Router::new()
        .route("/healthz", get(health_check))
        .route("/api/signals", get(get_signals_handler))
        .with_state(signals_collection_arc);

    // Start the server
    let addr = "0.0.0.0:8000";
    info!("🚀 Starting server on {}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
