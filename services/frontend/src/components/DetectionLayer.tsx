import React, { useEffect, useState } from 'react';
import { Circle, Group, Line } from 'react-konva';
import { Detection } from '../hooks/useData';
import { Tower } from '../hooks/useData';
import Konva from 'konva';

interface Props {
  detections: Detection[];
  towers: Tower[];
}

interface DetectionState {
  pulseSize: number;
  triangulationProgress: number;
  fadeOut: number;
}

const DetectionLayer: React.FC<Props> = ({ detections, towers }) => {
  const [activeDetections, setActiveDetections] = useState<Detection[]>([]);
  const [detectionStates, setDetectionStates] = useState<{ [key: string]: DetectionState }>({});
  const [isVisible, setIsVisible] = useState(true);

  useEffect(() => {
    const handleVisibilityChange = () => {
      setIsVisible(document.visibilityState === 'visible');
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, []);

  useEffect(() => {
    // Add detections one at a time with a delay
    const newDetections = detections.filter(d =>
      !activeDetections.some(ad => ad.x === d.x && ad.y === d.y)
    );

    if (newDetections.length > 0 && isVisible) {
      const timer = setTimeout(() => {
        setActiveDetections(prev => [...prev, newDetections[0]]);
      }, 1000); // Delay between each new detection
      return () => clearTimeout(timer);
    }
  }, [detections, activeDetections, isVisible]);

  useEffect(() => {
    // Initialize new detections
    const newStates = { ...detectionStates };

    activeDetections.forEach(detection => {
      const key = `${detection.x},${detection.y}`;
      if (!(key in newStates)) {
        newStates[key] = {
          pulseSize: 0,
          triangulationProgress: 0,
          fadeOut: 100
        };
      }
    });

    setDetectionStates(newStates);

    if (!isVisible) return;

    const interval = setInterval(() => {
      setDetectionStates(prev => {
        const next = { ...prev };
        let hasActiveAnimations = false;

        // Clean up completed animations
        const activeKeys = activeDetections.map(d => `${d.x},${d.y}`);
        Object.keys(next).forEach(key => {
          if (!activeKeys.includes(key)) {
            delete next[key];
          }
        });

        // Update all active states
        for (const key in next) {
          const state = next[key];

          // Update pulse size
          if (state.pulseSize < 20) {
            state.pulseSize += 1;
            hasActiveAnimations = true;
          }

          // Update triangulation progress
          if (state.triangulationProgress < 100) {
            state.triangulationProgress += 4;
            hasActiveAnimations = true;
          }
          // Start fade out after triangulation completes
          else if (state.fadeOut > 0) {
            state.fadeOut -= 2; // Fade out speed
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
  }, [activeDetections, isVisible]);

  return (
    <>
      {activeDetections.map((detection, i) => {
        const key = `${detection.x},${detection.y}`;
        const state = detectionStates[key] || { pulseSize: 0, triangulationProgress: 0, fadeOut: 100 };
        const { pulseSize, triangulationProgress, fadeOut } = state;

        // Don't render if animation is complete
        if (fadeOut <= 0) return null;

        return (
          <Group key={i}>
            {/* Triangulation lines */}
            {triangulationProgress > 20 && fadeOut > 0 && towers.map((tower, tIndex) => (
              <Line
                key={`${i}-${tIndex}`}
                points={[tower.x, tower.y, detection.x, detection.y]}
                stroke="#FF9800"
                strokeWidth={1.5}
                opacity={0.3 * (fadeOut / 100)}
                dash={[8, 4]}
                // Only show line up to current progress
                clipFunc={(ctx: Konva.Context) => {
                  const dx = detection.x - tower.x;
                  const dy = detection.y - tower.y;
                  const length = Math.sqrt(dx * dx + dy * dy);
                  const progressLength = (length * (triangulationProgress - 20)) / 80;

                  ctx.beginPath();
                  ctx.moveTo(tower.x, tower.y);
                  ctx.lineTo(
                    tower.x + (dx * progressLength) / length,
                    tower.y + (dy * progressLength) / length
                  );
                  ctx.lineTo(tower.x + dx, tower.y + dy);
                }}
              />
            ))}

            {/* Detection highlight */}
            <Circle
              x={detection.x}
              y={detection.y}
              radius={15}
              fill="rgba(255, 152, 0, 0.15)"
              stroke="#FF9800"
              strokeWidth={1.5}
              opacity={(triangulationProgress / 100) * (fadeOut / 100)}
              shadowColor="rgba(255, 152, 0, 0.2)"
              shadowBlur={10}
              shadowOpacity={0.2}
            />

            {/* Detection center */}
            <Circle
              x={detection.x}
              y={detection.y}
              radius={5}
              fill="#FF9800"
              stroke="white"
              strokeWidth={1.5}
              opacity={Math.max(triangulationProgress / 100, 0.4)}
            />

            {/* Pulse effect */}
            {pulseSize < 20 && (
              <Circle
                x={detection.x}
                y={detection.y}
                radius={15 + pulseSize * 2}
                fill="rgba(255, 152, 0, 0.1)"
                stroke="#FF9800"
                strokeWidth={1}
                opacity={(20 - pulseSize) / 20 * (triangulationProgress / 100)}
              />
            )}
          </Group>
        );
      })}
    </>
  );
};

export default DetectionLayer;
