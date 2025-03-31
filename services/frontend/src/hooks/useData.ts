import { useEffect, useState } from 'react';
import axios from 'axios';

const SIMULATION_BASE = import.meta.env.VITE_SIMULATION_BASE;
const SIGNAL_SOURCE_BASE = import.meta.env.VITE_SIGNAL_SOURCE_BASE;
const LOCATOR_BASE = import.meta.env.VITE_LOCATOR_BASE;

// Log environment variables (excluding sensitive data)
console.log('API Endpoints:', {
  SIMULATION_BASE,
  SIGNAL_SOURCE_BASE,
  LOCATOR_BASE
});

export interface Tower {
  id: string;
  x: number;
  y: number;
}

export interface Signal {
  x: number;
  y: number;
  timestamp: number;
}

export interface Detection {
  x: number;
  y: number;
  timestamp: number;
}

export const useData = () => {
  const [towers, setTowers] = useState<Tower[]>([]);
  const [signals, setSignals] = useState<Signal[]>([]);
  const [detections, setDetections] = useState<Detection[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let intervalId: number;
    let isVisible = true;

    const handleVisibilityChange = () => {
      isVisible = document.visibilityState === 'visible';
      if (isVisible) {
        // Clear data when returning to the tab
        setSignals([]);
        setDetections([]);
      }
    };

    const fetchData = async () => {
      if (!isVisible) return;

      try {
        // Fetch towers first as they're required for the visualization
        const tRes = await axios.get<Tower[]>(`${SIMULATION_BASE}/towers`);
        setTowers(tRes.data);

        // Then fetch signals and detections
        const [sRes, dRes] = await Promise.all([
          axios.get<Signal[]>(`${SIGNAL_SOURCE_BASE}/signals`),
          axios.get<Detection[]>(`${LOCATOR_BASE}/detections`)
        ]);

        if (sRes.data) setSignals(sRes.data);
        if (dRes.data) setDetections(dRes.data);

        setError(null);
      } catch (err) {
        console.error('❌ Failed to fetch data:', err);
        if (axios.isAxiosError(err)) {
          setError(`Failed to fetch data: ${err.message}${err.response ? ` (${err.response.status})` : ''}`);
          // Log more details about the error
          console.error('Error details:', {
            message: err.message,
            status: err.response?.status,
            data: err.response?.data,
            config: {
              url: err.config?.url,
              method: err.config?.method,
              headers: err.config?.headers
            }
          });
        } else {
          setError('An unexpected error occurred');
        }
      } finally {
        setLoading(false);
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    fetchData();
    intervalId = window.setInterval(fetchData, 5000);

    return () => {
      window.clearInterval(intervalId);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return { towers, signals, detections, loading, error };
};
