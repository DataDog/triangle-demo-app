import { Stage, Layer, Rect } from 'react-konva';
import { useData } from './hooks/useData';
import TowerLayer from './components/TowerLayer';
import SignalLayer from './components/SignalLayer';
import DetectionLayer from './components/DetectionLayer';
import Grid from './components/Grid';
import { useState, useEffect } from 'react';

const App = () => {
  const { towers, signals, detections, loading, error } = useData();
  const [stageSize, setStageSize] = useState(800);

  // Adjust stage size based on window size
  useEffect(() => {
    const updateSize = () => {
      const minSize = Math.min(window.innerWidth - 80, window.innerHeight - 200);
      setStageSize(Math.min(1000, Math.max(400, minSize)));
    };

    updateSize();
    window.addEventListener('resize', updateSize);
    return () => window.removeEventListener('resize', updateSize);
  }, []);

  return (
    <div style={{
      minHeight: '100vh',
      width: '100%',
      background: 'linear-gradient(to bottom, #1a237e, #000)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '20px'
    }}>
      <h1 style={{
        marginBottom: '30px',
        fontSize: 'clamp(1.5em, 4vw, 2.5em)',
        fontWeight: 'bold',
        color: 'white',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        textShadow: '0 2px 4px rgba(0,0,0,0.3)',
        textAlign: 'center'
      }}>
        <span role="img" aria-label="satellite" style={{ fontSize: '1.2em' }}>📡</span>
        Signal Triangulation System
      </h1>

      {error && (
        <div style={{
          background: 'rgba(244, 67, 54, 0.1)',
          border: '1px solid rgba(244, 67, 54, 0.3)',
          borderRadius: '8px',
          padding: '12px 20px',
          marginBottom: '20px',
          color: '#f44336',
          maxWidth: '80%',
          textAlign: 'center'
        }}>
          {error}
        </div>
      )}

      <div style={{
        background: 'white',
        borderRadius: '12px',
        padding: '20px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
        maxWidth: '100%',
        aspectRatio: '1',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <Stage width={stageSize} height={stageSize}>
          <Layer>
            {/* Background */}
            <Rect
              x={0}
              y={0}
              width={stageSize}
              height={stageSize}
              fill="#FAFAFA"
              shadowColor="rgba(0,0,0,0.1)"
              shadowBlur={20}
              shadowOffset={{ x: 0, y: 2 }}
            />

            {/* Visualization layers */}
            <Grid width={stageSize} height={stageSize} />
            <TowerLayer towers={towers || []} />
            <SignalLayer signals={signals || []} detections={detections || []} />
            <DetectionLayer detections={detections || []} towers={towers || []} />
          </Layer>
        </Stage>
      </div>

      <div style={{
        marginTop: '20px',
        color: 'rgba(255,255,255,0.9)',
        fontSize: 'clamp(0.8em, 2vw, 1em)',
        textAlign: 'center',
        maxWidth: '600px',
        textShadow: '0 1px 2px rgba(0,0,0,0.3)'
      }}>
        {loading ? 'Loading data...' : 'Real-time signal detection and triangulation visualization'}
      </div>
    </div>
  );
};

export default App;
