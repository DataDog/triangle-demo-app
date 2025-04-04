use mongodb::{Client, Collection};
use mongodb::bson::doc;
use crate::signal::Signal;
use tracing::{info, error};
use tokio;

pub async fn init_mongo() -> Result<(Client, Collection<Signal>, String), Box<dyn std::error::Error>> {
    let mongo_host = std::env::var("MONGO_HOST").unwrap_or_else(|_| "localhost".to_string());
    let mongo_username = std::env::var("MONGO_USERNAME").unwrap_or_else(|_| "mongouser".to_string());
    let mongo_password = std::env::var("MONGO_PASSWORD").unwrap_or_else(|_| "mongopass".to_string());
    let mongo_db = std::env::var("MONGO_DB").unwrap_or_else(|_| "triangle".to_string());
    let simulation_url = std::env::var("SIMULATION_URL").unwrap_or_else(|_| "http://localhost:8000/signal".to_string());

    info!("🔧 SIMULATION_URL = {}", simulation_url);

    let mongo_uri = format!(
        "mongodb://{}:{}@{}/{}?authSource=admin",
        mongo_username, mongo_password, mongo_host, mongo_db
    );
    info!("🔗 Mongo URI: {}", mongo_uri);
    info!("📨 Simulation URL: {}", simulation_url);

    // Try to connect to MongoDB with retries
    let mut retries = 0;
    const MAX_RETRIES: u32 = 5;
    const RETRY_DELAY: std::time::Duration = std::time::Duration::from_secs(2);

    let client = loop {
        match Client::with_uri_str(&mongo_uri).await {
            Ok(client) => {
                // Test the connection
                match client.database("admin").run_command(doc! {"ping": 1}).await {
                    Ok(_) => {
                        info!("✅ Successfully connected to MongoDB");
                        break client;
                    }
                    Err(e) => {
                        error!("❌ Failed to ping MongoDB: {}", e);
                        if retries >= MAX_RETRIES {
                            return Err(format!("Failed to connect to MongoDB after {} retries: {}", MAX_RETRIES, e).into());
                        }
                        retries += 1;
                        info!("⏳ Retrying MongoDB connection in {} seconds... (attempt {}/{})", RETRY_DELAY.as_secs(), retries, MAX_RETRIES);
                        tokio::time::sleep(RETRY_DELAY).await;
                    }
                }
            }
            Err(e) => {
                error!("❌ Failed to create MongoDB client: {}", e);
                if retries >= MAX_RETRIES {
                    return Err(format!("Failed to create MongoDB client after {} retries: {}", MAX_RETRIES, e).into());
                }
                retries += 1;
                info!("⏳ Retrying MongoDB connection in {} seconds... (attempt {}/{})", RETRY_DELAY.as_secs(), retries, MAX_RETRIES);
                tokio::time::sleep(RETRY_DELAY).await;
            }
        }
    };

    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    Ok((client, collection, simulation_url))
}
