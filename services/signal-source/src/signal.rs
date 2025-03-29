use serde::{Deserialize, Serialize};
use rand::Rng;
use rand::rngs::ThreadRng;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Signal {
    pub x: i32,
    pub y: i32,
    pub timestamp: i64,
}

pub fn generate_signal() -> Signal {
    let mut rng: ThreadRng = rand::thread_rng();
    let x = rng.gen_range(0..=1000);
    let y = rng.gen_range(0..=1000);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as i64;

    Signal { x, y, timestamp }
}
