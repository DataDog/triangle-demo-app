import React from 'react';
import { Line, Text } from 'react-konva';

interface Props {
  width: number;
  height: number;
  gridSize?: number;
}

const Grid: React.FC<Props> = ({ width, height, gridSize = 50 }) => {
  const lines = [];
  const coordinates = [];

  // Vertical lines and x-coordinates
  for (let x = 0; x <= width; x += gridSize) {
    lines.push(
      <Line
        key={`v${x}`}
        points={[x, 0, x, height]}
        stroke="#e5e5e5"
        strokeWidth={1}
      />
    );

    // Add x-coordinates every 200 pixels
    if (x % 200 === 0) {
      coordinates.push(
        <Text
          key={`x${x}`}
          x={x + 5}
          y={5}
          text={x.toString()}
          fontSize={10}
          fill="#999"
        />
      );
    }
  }

  // Horizontal lines and y-coordinates
  for (let y = 0; y <= height; y += gridSize) {
    lines.push(
      <Line
        key={`h${y}`}
        points={[0, y, width, y]}
        stroke="#e5e5e5"
        strokeWidth={1}
      />
    );

    // Add y-coordinates every 200 pixels
    if (y % 200 === 0) {
      coordinates.push(
        <Text
          key={`y${y}`}
          x={5}
          y={y + 5}
          text={y.toString()}
          fontSize={10}
          fill="#999"
        />
      );
    }
  }

  return (
    <>
      {lines}
      {coordinates}
    </>
  );
};

export default Grid;
