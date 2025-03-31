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
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Panic logger
    std::panic::set_hook(Box::new(|info| {
        eprintln!("🔥 PANIC: {}", info);
        eprintln!("🔥 Backtrace: {:?}", std::backtrace::Backtrace::force_capture());
    }));

    println!("🚀 Signal source starting...");
    io::stdout().flush().unwrap();

    // Initialize MongoDB + read simulation URL
    println!("🔌 Initializing MongoDB connection...");
    let (mongo_client, signal_collection, simulation_url) = init_mongo().await;
    println!("✅ MongoDB connection successful");

    // Create a flag to track if the signal loop is running
    let signal_loop_running = Arc::new(AtomicBool::new(false));
    let signal_loop_running_clone = signal_loop_running.clone();

    // Start background signal generation loop
    println!("🔄 Starting signal generation loop...");
    start_signal_loop(signal_collection.clone(), simulation_url.clone(), signal_loop_running_clone);

    // Start Actix web server
    println!("🌐 Starting HTTP server on 0.0.0.0:8000");
    match HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(mongo_client.clone()))
            .app_data(web::Data::new(simulation_url.clone()))
            .app_data(web::Data::new(signal_loop_running.clone()))
            .route("/healthz", web::get().to(healthz))
            .service(get_signals)
    })
    .bind(("0.0.0.0", 8000)) {
        Ok(server) => {
            println!("✅ HTTP server bound successfully");
            server.run().await
        }
        Err(e) => {
            eprintln!("❌ Failed to bind HTTP server: {}", e);
            std::process::exit(1);
        }
    }
}
