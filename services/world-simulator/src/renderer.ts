import { towers, signals } from "./state";
import { WORLD_SIZE, SPEED_OF_SOUND, SIGNAL_LIFETIME } from "./constants";

export function startRenderLoop(canvas: HTMLCanvasElement) {
  const ctx = canvas.getContext("2d")!;

  function draw() {
    const now = Date.now();
    ctx.clearRect(0, 0, WORLD_SIZE, WORLD_SIZE);

    towers.forEach((t, i) => {
      ctx.fillStyle = "blue";
      ctx.beginPath();
      ctx.arc(t.x, t.y, 8, 0, 2 * Math.PI);
      ctx.fill();
      ctx.fillStyle = "black";
      ctx.fillText(`Tower ${i + 1}`, t.x + 10, t.y - 10);
    });

    signals.forEach((signal) => {
      const elapsed = now - signal.time;
      if (elapsed > SIGNAL_LIFETIME) return;
      const radius = (elapsed / 1000) * SPEED_OF_SOUND;
      const alpha = 1 - elapsed / SIGNAL_LIFETIME;
      ctx.strokeStyle = `rgba(255, 0, 0, ${alpha.toFixed(2)})`;
      ctx.beginPath();
      ctx.arc(signal.x, signal.y, radius, 0, 2 * Math.PI);
      ctx.stroke();
    });

    requestAnimationFrame(draw);
  }

  draw();
}
