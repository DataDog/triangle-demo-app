use mongodb::{Client, Collection};
use crate::signal::Signal;
use std::env;

pub async fn init_mongo() -> (Client, Collection<Signal>, String) {
    let mongo_user = env::var("MONGO_USERNAME").unwrap_or_else(|_| "mongouser".into());
    let mongo_pass = env::var("MONGO_PASSWORD").unwrap_or_else(|_| "mongopass".into());
    let mongo_db = env::var("MONGO_DB").unwrap_or_else(|_| "triangle".into());
    let simulation_url = env::var("SIMULATION_URL").expect("❌ SIMULATION_URL must be set");

    let mongo_uri = format!(
        "mongodb://{}:{}@mongodb:27017/{}?authSource=admin",
        mongo_user, mongo_pass, mongo_db
    );

    println!("🔗 Mongo URI: {}", mongo_uri);
    println!("📨 Simulation URL: {}", simulation_url);

    let client = Client::with_uri_str(&mongo_uri).await.expect("❌ MongoDB connection failed");
    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    (client, collection, simulation_url)
}
