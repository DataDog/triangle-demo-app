use rand::Rng;
use serde::{Deserialize, Serialize};
use mongodb::{Client, Collection};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::time::{sleep, Duration};

#[derive(Debug, Serialize, Deserialize)]
struct Signal {
    x: i32,
    y: i32,
    timestamp: i64,
}

async fn generate_signal() -> Signal {
    let mut rng = rand::thread_rng();
    let x = rng.gen_range(0..=1000);
    let y = rng.gen_range(0..=1000);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as i64;

    Signal { x, y, timestamp }
}

async fn send_to_simulation(signal: &Signal, url: &str) {
    let client = reqwest::Client::new();
    let result = client
        .post(url)
        .json(signal)
        .send()
        .await;

    if let Err(err) = result {
        eprintln!("❌ Failed to send to simulation: {}", err);
    }
}

async fn insert_to_mongo(collection: &Collection<Signal>, signal: &Signal) {
    match collection.insert_one(signal).await {
        Ok(result) => println!("✅ Inserted signal into MongoDB: {:?}", result.inserted_id),
        Err(err) => eprintln!("❌ Failed to insert into MongoDB: {}", err),
    }
}

#[tokio::main]
async fn main() {
    println!("🚀 Signal source starting...");

    let mongo_user = std::env::var("MONGO_USERNAME").unwrap_or_else(|_| "mongouser".into());
    let mongo_pass = std::env::var("MONGO_PASSWORD").unwrap_or_else(|_| "mongopass".into());
    let mongo_db = std::env::var("MONGO_DB").unwrap_or_else(|_| "triangle".into());
    let simulation_url = std::env::var("SIMULATION_URL")
        .expect("❌ SIMULATION_URL must be set via environment variable");

    let mongo_uri = format!(
        "mongodb://{}:{}@mongodb:27017/{}?authSource=admin",
        mongo_user, mongo_pass, mongo_db
    );

    println!("🔗 Mongo URI: {}", mongo_uri);
    println!("📨 Simulation URL: {}", simulation_url);

    let client = match Client::with_uri_str(&mongo_uri).await {
        Ok(c) => c,
        Err(err) => {
            eprintln!("❌ Failed to connect to MongoDB: {}", err);
            return;
        }
    };

    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    loop {
        let signal = generate_signal().await;
        println!("📡 Generated signal: {:?}", signal);

        insert_to_mongo(&collection, &signal).await;
        send_to_simulation(&signal, &simulation_url).await;

        sleep(Duration::from_secs(5)).await;
    }
}
