# Triangle Frontend Service

A React-based frontend service for visualizing signal triangulation and detection data in real-time.

## Features

- Real-time visualization of signal sources and detections
- Interactive map interface using Konva.js
- Smooth animations for signal appearances and triangulation
- Visibility-aware signal processing (ignores signals when window is not visible)
- Responsive design that works across different screen sizes

## Tech Stack

- React 18
- TypeScript
- Vite
- Konva.js for canvas-based rendering
- ESLint for code quality

## Project Structure

```
src/
├── components/         # React components
│   ├── DetectionLayer.tsx  # Handles detection visualization
│   ├── SignalLayer.tsx     # Handles signal visualization
│   └── ...
├── hooks/             # Custom React hooks
│   └── useData.ts     # Data fetching and state management
└── ...
```
