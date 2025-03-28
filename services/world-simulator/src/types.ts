export interface Tower {
  id: number;
  x: number;
  y: number;
}

export interface Signal {
  x: number;
  y: number;
  time: number; // ms since epoch
}

export type EventPayload =
  | { type: "signal"; data: Signal }
  | { type: "detection"; data: { towerId: number; signal: Signal; time: number } };
