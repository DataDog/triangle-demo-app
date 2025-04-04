use crate::signal::generate_signal;
use reqwest::Client as HttpClient;
use tokio::time::{sleep, Duration};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::io;
use tracing::{info, error, warn};
use tracing::instrument;
use opentelemetry::{global};
use opentelemetry_sdk::{propagation::TraceContextPropagator, trace as sdktrace};
use opentelemetry_stdout::SpanExporter;
use opentelemetry::trace::{SpanKind, Tracer};
use mongodb::Collection;

use crate::signal::Signal;

/// Optional: Only needed if you need to re-init the tracer here.
/// If you're already doing that in `main.rs`, you can remove this.
fn init_tracer() -> sdktrace::SdkTracerProvider {
    global::set_text_map_propagator(TraceContextPropagator::new());
    let provider = sdktrace::SdkTracerProvider::builder()
        .with_simple_exporter(SpanExporter::default())
        .build();

    global::set_tracer_provider(provider.clone());
    provider
}

#[instrument(skip(http_client))]
async fn wait_for_simulation(http_client: &HttpClient, health_url: &str) -> io::Result<()> {
    let mut attempts = 0;
    const MAX_ATTEMPTS: u32 = 5; // Adjust as needed
    const RETRY_DELAY: Duration = Duration::from_secs(2);

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
        info!("⏳ Waiting for simulation service to become available... (attempt {}/{})",
              attempts, MAX_ATTEMPTS);
        sleep(RETRY_DELAY).await;
    }

    warn!("⚠️ Could not connect to simulation service after {} attempts. Continuing anyway...",
          MAX_ATTEMPTS);
    Ok(())
}

/// Runs the main signal generation loop, inserting into MongoDB and
/// sending signals to the simulation service.
///
/// `signals` is now `Arc<Collection<Signal>>` so we can clone it safely
/// in a background task without lifetime or Send issues.
pub async fn run_signal_loop(
    mongo_client: mongodb::Client,
    signals: Arc<Collection<Signal>>,
    simulation_url: String,
    running: Arc<AtomicBool>,
) -> Result<(), Box<dyn std::error::Error>> {
    let http_client = HttpClient::new();

    let tracer = global::tracer("server");
    let _span = tracer
        .span_builder("signal_loop")
        .with_kind(SpanKind::Server)
        .start(&tracer);

    info!("🚀 Starting signal loop");
    info!("📡 Simulation URL: {}", simulation_url);

    // Wait for simulation service to be ready
    let health_url = format!("{}/healthz", simulation_url.trim_end_matches("/signal"));
    wait_for_simulation(&http_client, &health_url).await?;

    // Run the loop until the running flag is set to false
    while running.load(Ordering::Relaxed) {
        let signal = generate_signal();
        info!("📊 Generated signal: {:?}", signal);

        // Insert into MongoDB
        match signals.insert_one(signal.clone()).await {
            Ok(_) => {
                info!("💾 Signal inserted into MongoDB");
            }
            Err(err) => {
                error!("❌ Failed to insert signal into MongoDB: {}", err);
                continue;
            }
        }

        // Send the signal to the simulation service
        match http_client.post(&simulation_url).json(&signal).send().await {
            Ok(_) => {
                info!("📤 Signal sent to simulation service");
            }
            Err(err) => {
                error!("❌ Failed to send signal to simulation service: {}", err);
            }
        }

        info!("✅ Loop iteration completed");
        sleep(Duration::from_secs(1)).await;
    }

    info!("🛑 Signal loop stopped");
    Ok(())
}
