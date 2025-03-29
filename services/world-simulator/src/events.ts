import type { EventPayload } from "./types";
import { sendSignal } from "./api";

export function handleIncomingEvent(event: EventPayload) {
  switch (event.type) {
    case "signal":
      console.log("Signal event:", event.data);
      sendSignal(event.data).catch(error => {
        console.error("Failed to send signal to base tower:", error);
      });
      break;
    case "detection":
      console.log("Detection event:", event.data);
      break;
  }
}
