use actix_web::{web, HttpResponse, Responder};
use mongodb::bson::doc;
use mongodb::Client;
use reqwest::Client as HttpClient;

pub async fn healthz(
    mongo_client: web::Data<Client>,
    simulation_url: web::Data<String>
) -> impl Responder {
    // Check Mongo
    let db = mongo_client.database("admin");
    if db.run_command(doc! {"ping": 1}).await.is_err() {
        return HttpResponse::ServiceUnavailable().body("mongo unreachable");
    }

    // Check Simulation
    let client = HttpClient::new();
    let sim_url = format!("{}/healthz", simulation_url.get_ref());
    if client.get(&sim_url).send().await.is_err() {
        return HttpResponse::ServiceUnavailable().body("simulation unreachable");
    }

    HttpResponse::Ok().body("ok")
}
