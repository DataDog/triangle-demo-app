import { Signal } from "./types";

const baseUrl = import.meta.env.VITE_BASE_TOWER_URL ?? '';

if (!baseUrl) {
  throw new Error('VITE_BASE_TOWER_URL environment variable is not set');
}

const API_BASE_URL = baseUrl;

export async function sendSignal(signal: Signal) {
  try {
    console.log('Sending signal to:', `${API_BASE_URL}/signal`);
    console.log('Signal data:', signal);

    const response = await fetch(`${API_BASE_URL}/signal`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(signal),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    console.log('Signal sent successfully:', result);
    return result;
  } catch (error) {
    console.error('Error sending signal to base tower:', error);
    throw error;
  }
}
