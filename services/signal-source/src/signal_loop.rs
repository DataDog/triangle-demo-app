use crate::signal::Signal;
use crate::signal::generate_signal;
use mongodb::Collection;
use reqwest::Client as HttpClient;
use tokio::time::{sleep, Duration};
use rand::rngs::StdRng;
use rand::SeedableRng;
use rand::thread_rng;
use rand::Rng;

pub fn start_signal_loop(collection: Collection<Signal>, simulation_url: String) {
    tokio::spawn(run_loop(collection, simulation_url));
}

async fn run_loop(collection: Collection<Signal>, simulation_url: String) {
    let http_client = HttpClient::new();
    let health_url = format!("{}/healthz", simulation_url.trim_end_matches("/signal"));
    wait_for_simulation(&http_client, &health_url).await;

    // Create a thread-safe RNG
    let mut rng = StdRng::from_rng(thread_rng()).unwrap();

    loop {
        // Generate all random values before any async operations
        let delay = if rng.gen_ratio(1, 5) {
            // Rapid signals
            rng.gen_range(500..1000)
        } else if rng.gen_ratio(3, 4) {
            // Normal signals
            rng.gen_range(2000..4000)
        } else {
            // Slower signals
            rng.gen_range(5000..8000)
        };

        let signal = generate_signal();
        println!("📡 Generated signal: {:?}", signal);

        match collection.insert_one(&signal).await {
            Ok(result) => println!("✅ Inserted into MongoDB: {:?}", result.inserted_id),
            Err(err) => eprintln!("❌ Mongo insert failed: {}", err),
        }

        let response = http_client.post(&simulation_url).json(&signal).send().await;
        if let Err(err) = response {
            eprintln!("❌ Failed to send to simulation: {}", err);
        }

        sleep(Duration::from_millis(delay)).await;
    }
}

async fn wait_for_simulation(http_client: &HttpClient, health_url: &str) {
    loop {
        match http_client.get(health_url).send().await {
            Ok(res) if res.status().is_success() => {
                println!("✅ Simulation service is reachable. Starting signal loop.");
                break;
            }
            _ => {
                println!("⏳ Waiting for simulation service to become available...");
                sleep(Duration::from_secs(2)).await;
            }
        }
    }
}
