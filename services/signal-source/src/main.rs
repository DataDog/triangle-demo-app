use rand::Rng;
use serde::{Deserialize, Serialize};
use mongodb::{bson::doc, Client, Collection};
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

async fn send_to_simulation(signal: &Signal) {
    let client = reqwest::Client::new();
    let result = client
        .post("http://simulation:8000/signal")
        .json(signal)
        .send()
        .await;

    if let Err(err) = result {
        eprintln!("❌ Failed to send to simulation: {}", err);
    }
}

async fn insert_to_mongo(collection: &Collection<Signal>, signal: &Signal) {
    if let Err(err) = collection.insert_one(signal).await {
        eprintln!("❌ Failed to insert into MongoDB: {}", err);
    }
}

#[tokio::main]
async fn main() {
    println!("🚀 Signal source starting...");

    let mongo_uri = std::env::var("MONGO_URI").unwrap_or_else(|_| {
        eprintln!("⚠️  MONGO_URI not set, defaulting to mongodb://mongodb:27017");
        "mongodb://mongodb:27017".into()
    });

    let client = match Client::with_uri_str(&mongo_uri).await {
        Ok(c) => c,
        Err(err) => {
            eprintln!("❌ Failed to connect to MongoDB: {}", err);
            return;
        }
    };

    let db = client.database("signalsim");
    let collection = db.collection::<Signal>("signals");

    loop {
        let signal = generate_signal().await;
        println!("📡 Generated signal: {:?}", signal);

        insert_to_mongo(&collection, &signal).await;
        send_to_simulation(&signal).await;

        sleep(Duration::from_secs(5)).await;
    }
}
