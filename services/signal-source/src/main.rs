mod mongo;
mod signal;
mod signal_loop;
mod health;

use actix_web::{web, App, HttpServer};
use mongo::init_mongo;
use signal_loop::start_signal_loop;
use health::healthz;
use signal::get_signals;
use std::io::{self, Write};

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Panic logger
    std::panic::set_hook(Box::new(|info| {
        eprintln!("🔥 PANIC: {}", info);
        io::stderr().flush().unwrap();
    }));

    println!("🚀 Signal source starting...");
    io::stdout().flush().unwrap();

    // Initialize MongoDB + read simulation URL
    println!("🔧 Initializing MongoDB connection...");
    io::stdout().flush().unwrap();

    let (mongo_client, signal_collection, simulation_url) = match init_mongo().await {
        Ok(result) => {
            println!("✅ MongoDB initialized successfully");
            io::stdout().flush().unwrap();
            result
        },
        Err(e) => {
            eprintln!("❌ Failed to initialize MongoDB: {}", e);
            io::stderr().flush().unwrap();
            std::process::exit(1);
        }
    };

    // Start background signal generation loop
    start_signal_loop(signal_collection.clone(), simulation_url.clone());

    // Start Actix web server
    println!("🌐 Starting HTTP server on 0.0.0.0:8000");
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(mongo_client.clone()))
            .app_data(web::Data::new(simulation_url.clone()))
            .route("/healthz", web::get().to(healthz))
            .service(get_signals)
    })
    .bind(("0.0.0.0", 8000))?
    .run()
    .await
}
