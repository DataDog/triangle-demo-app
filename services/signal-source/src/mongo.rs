use mongodb::{Client, Collection};
use crate::signal::Signal;
use std::io;
use tracing::info;

pub async fn init_mongo() -> io::Result<(Client, Collection<Signal>, String)> {
    let mongo_user = std::env::var("MONGO_USERNAME").map_err(|e| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("MONGO_USERNAME not set: {}", e)
        )
    })?;

    let mongo_pass = std::env::var("MONGO_PASSWORD").map_err(|e| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("MONGO_PASSWORD not set: {}", e)
        )
    })?;

    let mongo_db = std::env::var("MONGO_DB").map_err(|e| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("MONGO_DB not set: {}", e)
        )
    })?;

    let mongo_host = std::env::var("MONGO_HOST").unwrap_or_else(|_| "mongodb:27017".to_string());

    let simulation_url = std::env::var("SIMULATION_URL").map_err(|e| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("SIMULATION_URL not set: {}", e)
        )
    })?;

    info!("🔧 SIMULATION_URL = {}", simulation_url);
    let mongo_uri = format!(
        "mongodb://{}:{}@{}/{}?authSource=admin",
        mongo_user, mongo_pass, mongo_host, mongo_db
    );

    info!("🔗 Mongo URI: {}", mongo_uri);
    info!("📨 Simulation URL: {}", simulation_url);

    let client = Client::with_uri_str(&mongo_uri)
        .await
        .map_err(|e| {
            io::Error::new(
                io::ErrorKind::ConnectionRefused,
                format!("MongoDB connection failed: {}", e)
            )
        })?;

    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    Ok((client, collection, simulation_url))
}
