import { defineConfig } from 'vite';
import fs from 'fs';

console.log("🚨 VITE_BASE_TOWER_URL =", process.env.VITE_BASE_TOWER_URL);

fs.writeFileSync('debug-env.json', JSON.stringify({
  injected: process.env.VITE_BASE_TOWER_URL
}, null, 2));

export default defineConfig({
  define: {
    'import.meta.env': {
      VITE_BASE_TOWER_URL: JSON.stringify(process.env.VITE_BASE_TOWER_URL || '')
    }
  },
  build: {
    rollupOptions: {
      output: {
        entryFileNames: `assets/[name].js`,
        chunkFileNames: `assets/[name].js`,
        assetFileNames: `assets/[name].[ext]`
      }
    }
  }
});
