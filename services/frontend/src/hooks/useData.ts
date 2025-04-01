import { useEffect, useState } from 'react';
import axios from 'axios';

// Use relative paths for API endpoints
const SIMULATION_BASE = '/api/simulation/towers';
const SIGNAL_SOURCE_BASE = '/api/signals/signals';
const LOCATOR_BASE = '/api/locator/detections';

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
    let isMounted = true;

    const handleVisibilityChange = () => {
      isVisible = document.visibilityState === 'visible';
      if (isVisible && isMounted) {
        // Clear data when returning to the tab
        setSignals([]);
        setDetections([]);
      }
    };

    const fetchData = async () => {
      if (!isVisible || !isMounted) return;

      try {
        // Fetch towers first as they're required for the visualization
        const tRes = await axios.get<Tower[]>(SIMULATION_BASE);
        if (!isMounted) return;
        setTowers(tRes.data || []);

        // Then fetch signals and detections
        const [sRes, dRes] = await Promise.all([
          axios.get<Signal[]>(SIGNAL_SOURCE_BASE),
          axios.get<Detection[]>(LOCATOR_BASE)
        ]);

        if (!isMounted) return;
        setSignals(sRes.data || []);
        setDetections(dRes.data || []);
        setError(null);
      } catch (err) {
        if (!isMounted) return;
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
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    fetchData();
    intervalId = window.setInterval(fetchData, 5000);

    return () => {
      isMounted = false;
      window.clearInterval(intervalId);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return {
    towers: towers || [],
    signals: signals || [],
    detections: detections || [],
    loading,
    error
  };
};
