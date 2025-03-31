import React from 'react';
import { Circle, Text, Group } from 'react-konva';
import { Tower } from '../hooks/useData';

interface Props {
  towers: Tower[];
}

export const TowerLayer: React.FC<Props> = ({ towers }) => {
  return (
    <>
      {towers.map((tower, i) => (
        <Group key={tower.id}>
          {/* Tower base shadow */}
          <Circle
            x={tower.x}
            y={tower.y}
            radius={12}
            fill="rgba(0, 0, 0, 0.1)"
            stroke="none"
          />
          {/* Tower base */}
          <Circle
            x={tower.x}
            y={tower.y}
            radius={10}
            fill="#1976D2"
            stroke="white"
            strokeWidth={2}
          />
          {/* Tower label */}
          <Text
            x={tower.x + 15}
            y={tower.y - 10}
            text={`Tower ${i + 1}`}
            fontSize={14}
            fill="#1976D2"
            fontStyle="bold"
          />
        </Group>
      ))}
    </>
  );
};

export default TowerLayer;
