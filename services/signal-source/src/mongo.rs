use mongodb::{Client, Collection};
use crate::signal::Signal;

pub async fn init_mongo() -> (Client, Collection<Signal>, String) {

    let mongo_user = std::env::var("MONGO_USERNAME").unwrap_or_else(|_| {
        eprintln!("❌ MONGO_USERNAME not set");
        std::process::exit(1);
    });

    let mongo_pass = std::env::var("MONGO_PASSWORD").unwrap_or_else(|_| {
        eprintln!("❌ MONGO_PASSWORD not set");
        std::process::exit(1);
    });

    let mongo_db = std::env::var("MONGO_DB").unwrap_or_else(|_| {
        eprintln!("❌ MONGO_DB not set");
        std::process::exit(1);
    });

    let simulation_url = std::env::var("SIMULATION_URL").unwrap_or_else(|_| {
        eprintln!("❌ SIMULATION_URL not set");
        std::process::exit(1);
    });

    println!("🔧 SIMULATION_URL = {simulation_url}");
    let mongo_uri = format!(
        "mongodb://{}:{}@mongodb:27017/{}?authSource=admin",
        mongo_user, mongo_pass, mongo_db
    );

    println!("🔗 Mongo URI: {}", mongo_uri);
    println!("📨 Simulation URL: {}", simulation_url);

    let client = Client::with_uri_str(&mongo_uri)
        .await
        .expect("❌ MongoDB connection failed");

    let db = client.database(&mongo_db);
    let collection = db.collection::<Signal>("signals");

    (client, collection, simulation_url)
}
