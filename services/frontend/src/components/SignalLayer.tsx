import React from 'react';
import { Circle, Arrow, Group } from 'react-konva';
import { Signal } from '../hooks/useData';

interface Props {
  signals: Signal[];
}

const SignalLayer: React.FC<Props> = ({ signals }) => {
  return (
    <>
      {signals.map((signal, i) => (
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
          />

          {/* Signal source */}
          <Circle
            x={signal.x}
            y={signal.y}
            radius={4}
            fill="#4CAF50"
            stroke="white"
            strokeWidth={2}
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
              opacity={0.6}
              pointerLength={4}
              pointerWidth={4}
            />
          ))}
        </Group>
      ))}
    </>
  );
};

export default SignalLayer;
