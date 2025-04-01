use actix_web::{web, HttpResponse, Responder};
use mongodb::bson::doc;
use mongodb::Client;
use reqwest::Client as HttpClient;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

pub async fn healthz(
    mongo_client: web::Data<Client>,
    simulation_url: web::Data<String>,
    signal_loop_running: web::Data<Arc<AtomicBool>>,
) -> impl Responder {
    // Check Mongo
    let db = mongo_client.database("triangle");
    match db.run_command(doc! {"ping": 1}).await {
        Ok(_) => println!("✅ MongoDB health check passed"),
        Err(e) => {
            eprintln!("❌ MongoDB health check failed: {}", e);
            return HttpResponse::ServiceUnavailable().body("mongo unreachable");
        }
    }

    // Check Simulation - only if signal loop is running
    if signal_loop_running.load(std::sync::atomic::Ordering::SeqCst) {
        let client = HttpClient::new();
        let sim_url = format!("{}/healthz", simulation_url.get_ref().trim_end_matches("/signal"));
        match client.get(&sim_url).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    println!("✅ Simulation service health check passed");
                } else {
                    eprintln!("❌ Simulation service returned non-200 status: {}", response.status());
                    return HttpResponse::ServiceUnavailable().body("simulation service unhealthy");
                }
            }
            Err(e) => {
                eprintln!("❌ Simulation service health check failed: {}", e);
                return HttpResponse::ServiceUnavailable().body("simulation unreachable");
            }
        }
    } else {
        println!("⚠️ Signal loop not running yet, skipping simulation health check");
    }

    // Check signal loop
    if !signal_loop_running.load(std::sync::atomic::Ordering::SeqCst) {
        eprintln!("❌ Signal loop is not running");
        return HttpResponse::ServiceUnavailable().body("signal loop not running");
    }

    println!("✅ All health checks passed");
    HttpResponse::Ok().body("ok")
}
