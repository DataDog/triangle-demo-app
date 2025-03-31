import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/towers': 'http://localhost:8000',
      '/signals': 'http://localhost:8000',
      '/detections': 'http://localhost:8000'
    }
  }
});
