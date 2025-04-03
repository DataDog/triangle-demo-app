use crate::signal::Signal;
use crate::signal::generate_signal;
use mongodb::Collection;
use reqwest::Client as HttpClient;
use tokio::time::{sleep, Duration};
use rand::rngs::StdRng;
use rand::SeedableRng;
use rand::thread_rng;
use rand::Rng;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::io;
use tracing::{info, error, warn};
use tracing::instrument;
use opentelemetry::{global, propagation::Injector};
use opentelemetry::trace::Span;
use opentelemetry_sdk::{propagation::TraceContextPropagator, trace as sdktrace};
use opentelemetry_stdout::SpanExporter;

use opentelemetry::{
    trace::{SpanKind, TraceContextExt, Tracer},
    Context, KeyValue,
};

fn init_tracer() -> sdktrace::SdkTracerProvider {
    global::set_text_map_propagator(TraceContextPropagator::new());
    // Install stdout exporter pipeline to be able to retrieve the collected spans.
    let provider = sdktrace::SdkTracerProvider::builder()
        .with_simple_exporter(SpanExporter::default())
        .build();

    global::set_tracer_provider(provider.clone());
    provider
}

pub async fn run_signal_loop(
    collection: Collection<Signal>,
    simulation_url: String,
    running: Arc<AtomicBool>,
) -> io::Result<()> {
    let http_client = HttpClient::new();
    let health_url = format!("{}/healthz", simulation_url.trim_end_matches("/signal"));

    info!("🔍 Checking simulation service health...");
    wait_for_simulation(&http_client, &health_url).await?;

    // Create a thread-safe RNG
    let mut rng = StdRng::from_rng(thread_rng()).unwrap();
    let mut consecutive_errors = 0;
    const MAX_CONSECUTIVE_ERRORS: u32 = 5;
    let tracer = global::tracer("signal-source");

    info!("✅ Starting signal generation loop");
    while running.load(Ordering::SeqCst) {
        // Create a new span for each signal generation cycle

        let mut span = tracer
        .span_builder("signal_generation")
        .with_kind(SpanKind::Internal)
        .start(&tracer);

        // Generate all random values before any async operations
        let delay = if rng.gen_ratio(1, 8) {
            // Occasional rapid signals (3-4 seconds)
            rng.gen_range(3000..4000)
        } else if rng.gen_ratio(2, 3) {
            // Normal signals (5-8 seconds)
            rng.gen_range(5000..8000)
        } else {
            // Slower signals (10-15 seconds)
            rng.gen_range(10000..15000)
        };

        let signal = generate_signal();
        span.add_event("Signal generated", vec![]);
        // Try to insert into MongoDB
        match collection.insert_one(&signal).await {
            Ok(result) => {
                span.add_event("Signal inserted into MongoDB", vec![]);
                consecutive_errors = 0;
            }
            Err(err) => {
                let error_msg = format!("MongoDB insert failed: {}", err);
                error!("❌ {}", error_msg);
                span.add_event("MongoDB insert failed", vec![KeyValue::new("error",error_msg.clone())]);
                consecutive_errors += 1;
                if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
                    return Err(io::Error::new(io::ErrorKind::Other, error_msg));
                }
            }
        }


        // Try to send to simulation service
        match http_client.post(&simulation_url).json(&signal).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    span.add_event("Sent Signal to Simulation Service", vec![KeyValue::new("status","OK")]);
                    consecutive_errors = 0;
                } else {
                    let error_msg = format!("Simulation service returned error status: {}", response.status());
                    error!("❌ {}", error_msg);
                    span.add_event("Simulation service returned error status", vec![KeyValue::new("error",error_msg.clone())]);
                    consecutive_errors += 1;
                    if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
                        return Err(io::Error::new(io::ErrorKind::Other, error_msg));
                    }
                }
            }
            Err(err) => {
                let error_msg = format!("Failed to send to simulation: {}", err);
                error!("❌ {}", error_msg);
                span.add_event("Failed to send to simulation", vec![KeyValue::new("error",error_msg.clone())]);
                consecutive_errors += 1;
                if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
                    return Err(io::Error::new(io::ErrorKind::Other, error_msg));
                }
            }
        }

        sleep(Duration::from_millis(delay)).await;
        span.add_event("Signal loop iteration completed", vec![KeyValue::new("delay", delay as i64)]);
    }
    info!("🛑 Signal loop stopped");
    Ok(())
}

#[instrument(skip(http_client))]
async fn wait_for_simulation(http_client: &HttpClient, health_url: &str) -> io::Result<()> {
    let mut attempts = 0;
    const MAX_ATTEMPTS: u32 = 30; // 1 minute total wait time

    while attempts < MAX_ATTEMPTS {
        match http_client.get(health_url).send().await {
            Ok(res) if res.status().is_success() => {
                info!("✅ Simulation service is reachable. Starting signal loop.");
                return Ok(());
            }
            Ok(res) => {
                warn!("⚠️ Simulation service returned non-200 status: {}", res.status());
            }
            Err(err) => {
                warn!("⚠️ Failed to reach simulation service: {}", err);
            }
        }
        attempts += 1;
        info!("⏳ Waiting for simulation service to become available... (attempt {}/{})", attempts, MAX_ATTEMPTS);
        sleep(Duration::from_secs(2)).await;
    }

    Err(io::Error::new(
        io::ErrorKind::ConnectionRefused,
        format!("Failed to connect to simulation service after {} attempts", MAX_ATTEMPTS),
    ))
}
