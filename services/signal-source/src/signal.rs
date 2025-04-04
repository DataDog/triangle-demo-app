use serde::{Deserialize, Serialize};
use rand::Rng;
use rand::rngs::ThreadRng;
use std::time::{SystemTime, UNIX_EPOCH};
use mongodb::{bson::doc, Collection};
use tracing::{info, error};
use futures::TryStreamExt;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Signal {
    pub x: i32,
    pub y: i32,
    pub timestamp: i64,
}

pub fn generate_signal() -> Signal {
    let mut rng: ThreadRng = rand::thread_rng();
    // Generate signals in a more structured pattern to test triangulation
    let pattern = rng.gen_range(0..100);

    let (x, y) = if pattern < 20 {
        // Center region - test accuracy near the centroid
        (
            rng.gen_range(400..600),
            rng.gen_range(400..600)
        )
    } else if pattern < 40 {
        // Outer circle - test radial accuracy
        let angle = rng.gen_range(0.0..2.0 * std::f64::consts::PI);
        let radius = rng.gen_range(250.0..350.0);
        (
            (500.0 + radius * angle.cos()) as i32,
            (500.0 + radius * angle.sin()) as i32
        )
    } else if pattern < 60 {
        // Grid pattern - systematic coverage
        let grid_x = rng.gen_range(2..8) * 100 + 100;
        let grid_y = rng.gen_range(2..8) * 100 + 100;
        (grid_x, grid_y)
    } else {
        // Random but avoid edges
        (
            rng.gen_range(200..800),
            rng.gen_range(200..800)
        )
    };

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as i64;

    Signal { x, y, timestamp }
}

pub async fn get_signals(signals: &Collection<Signal>) -> Result<Vec<Signal>, mongodb::error::Error> {
    info!("📥 Retrieving signals from MongoDB");

    match signals.find(doc! {}).await {
        Ok(cursor) => {
            match cursor.try_collect::<Vec<_>>().await {
                Ok(results) => {
                    info!("✅ Retrieved {} signals from MongoDB", results.len());
                    Ok(results)
                },
                Err(e) => {
                    error!("❌ Failed to collect signals: {}", e);
                    Err(e)
                }
            }
        },
        Err(e) => {
            error!("❌ Failed to query signals: {}", e);
            Err(e)
        }
    }
}
