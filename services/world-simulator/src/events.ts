import type { EventPayload } from "./types";

export function handleIncomingEvent(event: EventPayload) {
  switch (event.type) {
    case "signal":
      console.log("Signal event:", event.data);
      break;
    case "detection":
      console.log("Detection event:", event.data);
      break;
  }
}
