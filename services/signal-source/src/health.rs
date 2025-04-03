use actix_web::{web, HttpResponse, Responder};
use mongodb::bson::doc;
use mongodb::Client;
use reqwest::Client as HttpClient;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use tracing::{info, error, warn};

pub async fn healthz(
    mongo_client: web::Data<Client>,
    simulation_url: web::Data<String>,
    signal_loop_running: web::Data<Arc<AtomicBool>>,
) -> impl Responder {
    // Check MongoDB
    let db = mongo_client.database("triangle");
    match db.run_command(doc! {"ping": 1}).await {
        Ok(_) => info!("✅ MongoDB health check passed"),
        Err(e) => {
            error!("❌ MongoDB health check failed: {}", e);
            return HttpResponse::ServiceUnavailable().body("mongo unreachable");
        }
    }

    // Check Simulation Service - only if signal loop is running
    if signal_loop_running.load(std::sync::atomic::Ordering::SeqCst) {
        let client = HttpClient::new();
        let sim_url = format!("{}/healthz", simulation_url.get_ref().trim_end_matches("/signal"));
        match client.get(&sim_url).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    info!("✅ Simulation service health check passed");
                } else {
                    error!("❌ Simulation service returned non-200 status: {}", response.status());
                    return HttpResponse::ServiceUnavailable().body("simulation service unhealthy");
                }
            }
            Err(e) => {
                error!("❌ Simulation service health check failed: {}", e);
                return HttpResponse::ServiceUnavailable().body("simulation unreachable");
            }
        }
    } else {
        warn!("⚠️ Signal loop not running yet, skipping simulation health check");
    }

    // Check signal loop
    if !signal_loop_running.load(std::sync::atomic::Ordering::SeqCst) {
        error!("❌ Signal loop is not running");
        return HttpResponse::ServiceUnavailable().body("signal loop not running");
    }

    info!("✅ All health checks passed");
    HttpResponse::Ok().body("ok")
}
