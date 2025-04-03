mod mongo;
mod signal;
mod signal_loop;
mod health;

use actix_web::{web, App, HttpServer};
use mongo::init_mongo;
use signal_loop::run_signal_loop;
use health::healthz;
use std::io::{self, Write};
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::sync::OnceLock;
use opentelemetry::KeyValue;
use opentelemetry::{
    global,
    propagation::Extractor,
    trace::{Span, SpanKind, Tracer},
};
use opentelemetry_sdk::{propagation::TraceContextPropagator, trace::SdkTracerProvider};
use opentelemetry_stdout::SpanExporter;

fn init_tracer() -> SdkTracerProvider {
    global::set_text_map_propagator(TraceContextPropagator::new());
    // Install stdout exporter pipeline to be able to retrieve the collected spans.
    let provider = SdkTracerProvider::builder()
        .with_simple_exporter(SpanExporter::default())
        .build();

    global::set_tracer_provider(provider.clone());
    provider
}

#[tokio::main]
async fn main() -> io::Result<()> {
    // Initialize tracing with OpenTelemetry integration
    init_tracer();
    let tracer = global::tracer("server");
    let mut span = tracer
    .span_builder("main")
    .with_kind(SpanKind::Server)
    .start(&tracer);


    // Set a panic hook to capture and log panics with backtraces
    std::panic::set_hook(Box::new(|info| {
        let thread = std::thread::current();
        let thread_name = thread.name().unwrap_or("<unnamed>");
        eprintln!("🔥 PANIC in thread '{}': {}", thread_name, info);
        eprintln!("🔥 Backtrace: {:?}", std::backtrace::Backtrace::force_capture());
        std::io::stderr().flush().unwrap();
    }));

    span.add_event("Server is starting", vec![]);


    // Initialize MongoDB
    let (mongo_client, collection, simulation_url) = init_mongo().await.map_err(|e| {
        io::Error::new(
            io::ErrorKind::Other,
            format!("Failed to initialize MongoDB: {}", e),
        )
    })?;
    span.add_event("MongoDB initialized", vec![]);

    // Create a flag to control the signal loop
    let signal_loop_running = Arc::new(AtomicBool::new(true));

    // Spawn the signal loop in the background
    let signal_loop_running_clone = signal_loop_running.clone();
    let simulation_url_clone = simulation_url.clone();
    span.add_event("Signal loop spawned", vec![]);
    if let Err(e) = run_signal_loop(collection, simulation_url_clone, signal_loop_running_clone).await {
        tracing::error!("Signal loop encountered an error: {}", e);
    }

    // Build and run the HTTP server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(mongo_client.clone()))
            .app_data(web::Data::new(simulation_url.clone()))
            .app_data(web::Data::new(signal_loop_running.clone()))
            .route("/healthz", web::get().to(healthz))
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
