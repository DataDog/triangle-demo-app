import { EDGE_BUFFER, WORLD_SIZE, MIN_DISTANCE_BETWEEN_TOWERS, SIGNAL_INTERVAL_MS } from "./constants";
import { towers, signals } from "./state";
import { Signal } from "./types";
import { handleIncomingEvent } from "./events"

function randomCoord(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function distance(a: { x: number; y: number }, b: { x: number; y: number }): number {
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

export function placeTowers() {
  while (towers.length < 3) {
    const candidate = {
      x: randomCoord(EDGE_BUFFER, WORLD_SIZE - EDGE_BUFFER),
      y: randomCoord(EDGE_BUFFER, WORLD_SIZE - EDGE_BUFFER),
      id: towers.length + 1,
    };
    if (towers.every((t) => distance(t, candidate) >= MIN_DISTANCE_BETWEEN_TOWERS)) {
      towers.push(candidate);
    }
  }
}

export function generateSignal() {
  const signal: Signal = {
    x: randomCoord(0, WORLD_SIZE),
    y: randomCoord(0, WORLD_SIZE),
    time: Date.now(),
  };
  signals.push(signal);
  handleIncomingEvent({ type: "signal", data: signal });
}

export function startSimulation() {
  placeTowers();
  generateSignal();
  setInterval(generateSignal, SIGNAL_INTERVAL_MS);
}
