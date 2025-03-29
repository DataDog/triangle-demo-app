mod mongo;
mod signal;
mod signal_loop;
mod health;

use actix_web::{web, App, HttpServer};
use mongo::init_mongo;
use signal_loop::start_signal_loop;
use health::healthz;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    println!("🚀 Signal source starting...");

    let (mongo_client, signal_collection, simulation_url) = init_mongo().await;

    // start background signal generation loop
    start_signal_loop(signal_collection.clone(), simulation_url.clone());

    // start web server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(mongo_client.clone()))
            .app_data(web::Data::new(simulation_url.clone()))
            .route("/healthz", web::get().to(healthz))
    })
    .bind(("0.0.0.0", 8000))?
    .run()
    .await
}
