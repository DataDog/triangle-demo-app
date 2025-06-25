use mongodb::{Client, Collection};
use crate::signal::Signal;

pub async fn init_mongo() -> Result<(Client, Collection<Signal>, String), Box<dyn std::error::Error>> {

    let mongo_user = std::env::var("MONGO_USERNAME")
        .map_err(|_| "MONGO_USERNAME environment variable not set")?;

    let mongo_pass = std::env::var("MONGO_PASSWORD")
        .map_err(|_| "MONGO_PASSWORD environment variable not set")?;

    let mongo_db = std::env::var("MONGO_DB")
        .map_err(|_| "MONGO_DB environment variable not set")?;

    let simulation_url = std::env::var("SIMULATION_URL")
        .map_err(|_| "SIMULATION_URL environment variable not set")?;

    println!("🔧 SIMULATION_URL = {simulation_url}");
    let mongo_uri = format!(
        "mongodb://{}:{}@mongodb:27017/{}?authSource=admin",
        mongo_user, mongo_pass, mongo_db
    );

    let client = Client::with_uri_str(&mongo_uri)
        .await
        .map_err(|e| format!("MongoDB connection failed: {}", e))?;

    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    Ok((client, collection, simulation_url))
}
