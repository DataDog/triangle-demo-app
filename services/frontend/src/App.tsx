import { Stage, Layer, Rect } from 'react-konva';
import { useData } from './hooks/useData';
import TowerLayer from './components/TowerLayer';
import SignalLayer from './components/SignalLayer';
import DetectionLayer from './components/DetectionLayer';
import Grid from './components/Grid';

const App = () => {
  const { towers, signals, detections } = useData();
  const stageSize = 1000;

  return (
    <div style={{
      padding: '20px',
      background: 'linear-gradient(to bottom, #1a237e, #000)',
      minHeight: '100vh',
      color: 'white',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center'
    }}>
      <h1 style={{
        marginBottom: '20px',
        fontSize: '2.5em',
        fontWeight: 'bold',
        display: 'flex',
        alignItems: 'center',
        gap: '12px'
      }}>
        <span role="img" aria-label="satellite" style={{ fontSize: '1.2em' }}>📡</span>
        Signal Triangulation System
      </h1>

      <div style={{
        background: 'white',
        borderRadius: '12px',
        padding: '20px',
        boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        maxWidth: '100%',
        overflow: 'auto'
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
            />

            {/* Visualization layers */}
            <Grid width={stageSize} height={stageSize} />
            <TowerLayer towers={towers} />
            <DetectionLayer detections={detections} towers={towers} />
            <SignalLayer signals={signals} />
          </Layer>
        </Stage>
      </div>

      <div style={{
        marginTop: '20px',
        color: 'rgba(255,255,255,0.8)',
        fontSize: '0.9em',
        textAlign: 'center',
        maxWidth: '600px'
      }}>
        Real-time signal detection and triangulation visualization
      </div>
    </div>
  );
};

export default App;
