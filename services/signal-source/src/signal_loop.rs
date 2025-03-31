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

pub fn start_signal_loop(collection: Collection<Signal>, simulation_url: String, running: Arc<AtomicBool>) {
    // Set the running flag to true when we start
    running.store(true, Ordering::SeqCst);

    // Handle shutdown gracefully
    let running_clone = running.clone();
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.expect("Failed to listen for ctrl+c");
        println!("🛑 Received shutdown signal");
        running_clone.store(false, Ordering::SeqCst);
    });

    tokio::spawn(run_loop(collection, simulation_url, running));
}

async fn run_loop(collection: Collection<Signal>, simulation_url: String, running: Arc<AtomicBool>) {
    let http_client = HttpClient::new();
    let health_url = format!("{}/healthz", simulation_url.trim_end_matches("/signal"));

    println!("🔍 Checking simulation service health...");
    wait_for_simulation(&http_client, &health_url).await;

    // Create a thread-safe RNG
    let mut rng = StdRng::from_rng(thread_rng()).unwrap();
    let mut consecutive_errors = 0;
    const MAX_CONSECUTIVE_ERRORS: u32 = 5;

    while running.load(Ordering::SeqCst) {
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
        println!("📡 Generated signal: {:?}", signal);

        // Try to insert into MongoDB
        match collection.insert_one(&signal).await {
            Ok(result) => {
                println!("✅ Inserted into MongoDB: {:?}", result.inserted_id);
                consecutive_errors = 0;
            }
            Err(err) => {
                eprintln!("❌ Mongo insert failed: {}", err);
                consecutive_errors += 1;
            }
        }

        // Try to send to simulation service
        match http_client.post(&simulation_url).json(&signal).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    println!("✅ Sent to simulation service successfully");
                    consecutive_errors = 0;
                } else {
                    eprintln!("❌ Simulation service returned error status: {}", response.status());
                    consecutive_errors += 1;
                }
            }
            Err(err) => {
                eprintln!("❌ Failed to send to simulation: {}", err);
                consecutive_errors += 1;
            }
        }

        // Check for too many consecutive errors
        if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
            eprintln!("❌ Too many consecutive errors ({}), exiting...", consecutive_errors);
            running.store(false, Ordering::SeqCst);
            break;
        }

        sleep(Duration::from_millis(delay)).await;
    }
}

async fn wait_for_simulation(http_client: &HttpClient, health_url: &str) {
    let mut attempts = 0;
    const MAX_ATTEMPTS: u32 = 30; // 1 minute total wait time

    while attempts < MAX_ATTEMPTS {
        match http_client.get(health_url).send().await {
            Ok(res) if res.status().is_success() => {
                println!("✅ Simulation service is reachable. Starting signal loop.");
                return;
            }
            Ok(res) => {
                eprintln!("⚠️ Simulation service returned non-200 status: {}", res.status());
            }
            Err(err) => {
                eprintln!("⚠️ Failed to reach simulation service: {}", err);
            }
        }
        attempts += 1;
        println!("⏳ Waiting for simulation service to become available... (attempt {}/{})", attempts, MAX_ATTEMPTS);
        sleep(Duration::from_secs(2)).await;
    }

    eprintln!("❌ Failed to connect to simulation service after {} attempts", MAX_ATTEMPTS);
    std::process::exit(1);
}
