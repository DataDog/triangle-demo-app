import React, { useEffect, useState } from 'react';
import { Circle, Arrow, Group } from 'react-konva';
import { Signal, Detection } from '../hooks/useData';

interface Props {
  signals: Signal[];
  detections: Detection[];
}

interface SignalState {
  fadeOut: number;
}

const SignalLayer: React.FC<Props> = ({ signals }) => {
  const [signalStates, setSignalStates] = useState<{ [key: string]: SignalState }>({});
  const [isVisible, setIsVisible] = useState(true);
  const [processedSignals, setProcessedSignals] = useState<Set<string>>(new Set());
  const [isInitialLoad, setIsInitialLoad] = useState(true);

  useEffect(() => {
    const handleVisibilityChange = () => {
      setIsVisible(document.visibilityState === 'visible');
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, []);

  // Handle initial load
  useEffect(() => {
    if (isInitialLoad) {
      const initialSignals = new Set(signals.map(s => `${s.x},${s.y}`));
      setProcessedSignals(initialSignals);
      setIsInitialLoad(false);
    }
  }, [signals, isInitialLoad]);

  useEffect(() => {
    // Only initialize new signals if the window is visible
    if (!isVisible || isInitialLoad) return;

    const newStates = { ...signalStates };
    const newProcessedSignals = new Set(processedSignals);

    signals.forEach(signal => {
      const key = `${signal.x},${signal.y}`;
      // Only process signals that haven't been seen before
      if (!newProcessedSignals.has(key)) {
        newProcessedSignals.add(key);
        newStates[key] = {
          fadeOut: 100
        };
      }
    });

    setProcessedSignals(newProcessedSignals);
    setSignalStates(newStates);

    const interval = setInterval(() => {
      setSignalStates(prev => {
        const next = { ...prev };
        let hasActiveAnimations = false;

        // Clean up completed animations
        const activeKeys = signals.map(s => `${s.x},${s.y}`);
        Object.keys(next).forEach(key => {
          if (!activeKeys.includes(key)) {
            delete next[key];
          }
        });

        // Update all active states
        for (const key in next) {
          const state = next[key];
          if (state.fadeOut > 0) {
            state.fadeOut -= 1; // Fade out speed
            hasActiveAnimations = true;
          }
        }

        if (!hasActiveAnimations) {
          clearInterval(interval);
        }

        return next;
      });
    }, 50);

    return () => clearInterval(interval);
  }, [signals, isVisible, isInitialLoad]);

  return (
    <>
      {signals.map((signal, i) => {
        const key = `${signal.x},${signal.y}`;
        const state = signalStates[key] || { fadeOut: 100 };
        const { fadeOut } = state;

        // Don't render if animation is complete or if signal was processed while window was hidden
        // or if it's an initial signal
        if (fadeOut <= 0 || (processedSignals.has(key) && !signalStates[key]) || isInitialLoad) return null;

        return (
          <Group key={i}>
            {/* Signal glow effect */}
            <Circle
              x={signal.x}
              y={signal.y}
              radius={8}
              fill="rgba(76, 175, 80, 0.2)"
              shadowColor="#4CAF50"
              shadowBlur={10}
              shadowOpacity={0.3}
              opacity={fadeOut / 100}
            />

            {/* Signal source */}
            <Circle
              x={signal.x}
              y={signal.y}
              radius={4}
              fill="#4CAF50"
              stroke="white"
              strokeWidth={2}
              opacity={fadeOut / 100}
            />

            {/* Direction indicators */}
            {[0, 120, 240].map((angle) => (
              <Arrow
                key={angle}
                points={[
                  signal.x,
                  signal.y,
                  signal.x + Math.cos(angle * Math.PI / 180) * 15,
                  signal.y + Math.sin(angle * Math.PI / 180) * 15
                ]}
                fill="#4CAF50"
                stroke="#4CAF50"
                strokeWidth={1}
                opacity={0.6 * (fadeOut / 100)}
                pointerLength={4}
                pointerWidth={4}
              />
            ))}
          </Group>
        );
      })}
    </>
  );
};

export default SignalLayer;
