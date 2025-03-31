import { useEffect, useState } from 'react';
import axios from 'axios';

const SIMULATION_BASE = import.meta.env.VITE_SIMULATION_BASE;
const SIGNAL_SOURCE_BASE = import.meta.env.VITE_SIGNAL_SOURCE_BASE;
const LOCATOR_BASE = import.meta.env.VITE_LOCATOR_BASE;

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
        const [tRes, sRes, dRes] = await Promise.all([
          axios.get<Tower[]>(`${SIMULATION_BASE}/towers`),
          axios.get<Signal[]>(`${SIGNAL_SOURCE_BASE}/signals`),
          axios.get<Detection[]>(`${LOCATOR_BASE}/detections`)
        ]);

        setTowers(tRes.data);
        setSignals(sRes.data);
        setDetections(dRes.data);
      } catch (err) {
        console.error('❌ Failed to fetch simulation data:', err);
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

  return { towers, signals, detections, loading };
};
