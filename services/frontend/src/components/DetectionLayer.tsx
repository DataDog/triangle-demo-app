import React, { useEffect, useState } from 'react';
import { Circle, Group, Line } from 'react-konva';
import { Detection } from '../hooks/useData';
import { Tower } from '../hooks/useData';
import Konva from 'konva';

interface Props {
  detections: Detection[];
  towers: Tower[];
}

const DetectionLayer: React.FC<Props> = ({ detections, towers }) => {
  const [pulseSizes, setPulseSizes] = useState<{ [key: string]: number }>({});
  const [triangulationProgress, setTriangulationProgress] = useState<{ [key: string]: number }>({});

  useEffect(() => {
    // Initialize new detections
    const newPulseSizes = { ...pulseSizes };
    const newTriangulationProgress = { ...triangulationProgress };

    detections.forEach(detection => {
      const key = `${detection.x},${detection.y}`;
      if (!(key in newPulseSizes)) {
        newPulseSizes[key] = 0;
        newTriangulationProgress[key] = 0;
      }
    });

    setPulseSizes(newPulseSizes);
    setTriangulationProgress(newTriangulationProgress);

    const interval = setInterval(() => {
      setPulseSizes(prev => {
        const next = { ...prev };
        let hasActivePulses = false;

        Object.keys(next).forEach(key => {
          if (next[key] < 20) {
            next[key] += 1;
            hasActivePulses = true;
          }
        });

        if (!hasActivePulses) {
          clearInterval(interval);
        }
        return next;
      });

      // Update triangulation progress
      setTriangulationProgress(prev => {
        const next = { ...prev };
        let hasActiveTriangulation = false;

        Object.keys(next).forEach(key => {
          if (next[key] < 100) {
            next[key] += 2; // Adjust speed of triangulation animation
            hasActiveTriangulation = true;
          }
        });

        if (!hasActiveTriangulation) {
          clearInterval(interval);
        }

        return next;
      });
    }, 50);

    return () => clearInterval(interval);
  }, [detections]);

  return (
    <>
      {detections.map((detection, i) => {
        const key = `${detection.x},${detection.y}`;
        const pulseSize = pulseSizes[key] || 0;
        const progress = triangulationProgress[key] || 0;

        return (
          <Group key={i}>
            {/* Triangulation lines */}
            {towers.map((tower, tIndex) => (
              <Line
                key={`${i}-${tIndex}`}
                points={[tower.x, tower.y, detection.x, detection.y]}
                stroke="#FFC107"
                strokeWidth={1}
                opacity={0.3}
                dash={[5, 5]}
                // Only show line up to current progress
                clipFunc={(ctx: Konva.Context) => {
                  const dx = detection.x - tower.x;
                  const dy = detection.y - tower.y;
                  const length = Math.sqrt(dx * dx + dy * dy);
                  const progressLength = (length * progress) / 100;

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
              fill="rgba(255, 193, 7, 0.2)"
              stroke="#FFC107"
              strokeWidth={2}
              opacity={progress / 100}
            />

            {/* Detection center */}
            <Circle
              x={detection.x}
              y={detection.y}
              radius={6}
              fill="#FFC107"
              stroke="white"
              strokeWidth={2}
              opacity={progress / 100}
            />

            {/* Pulse effect */}
            {pulseSize < 20 && (
              <Circle
                x={detection.x}
                y={detection.y}
                radius={15 + pulseSize * 2}
                fill="rgba(255, 193, 7, 0.1)"
                stroke="#FFC107"
                strokeWidth={1}
                opacity={(20 - pulseSize) / 20 * (progress / 100)}
              />
            )}
          </Group>
        );
      })}
    </>
  );
};

export default DetectionLayer;
