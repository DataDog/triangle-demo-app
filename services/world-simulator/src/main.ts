import { startSimulation } from "./simulation";
import { startRenderLoop } from "./renderer";

document.addEventListener("DOMContentLoaded", () => {
  const canvas = document.getElementById("world") as HTMLCanvasElement;
  startRenderLoop(canvas);
  startSimulation();
});
