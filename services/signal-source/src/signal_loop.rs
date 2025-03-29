use crate::signal::Signal;
use crate::signal::generate_signal;
use mongodb::Collection;
use reqwest::Client as HttpClient;
use tokio::time::{sleep, Duration};

pub fn start_signal_loop(collection: Collection<Signal>, simulation_url: String) {
    tokio::spawn(run_loop(collection, simulation_url));
}

async fn run_loop(collection: Collection<Signal>, simulation_url: String) {
    let http_client = HttpClient::new();
    let health_url = format!("{}/healthz", simulation_url.trim_end_matches("/signal"));
    wait_for_simulation(&http_client, &health_url).await;

    loop {
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

        sleep(Duration::from_secs(5)).await;
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
