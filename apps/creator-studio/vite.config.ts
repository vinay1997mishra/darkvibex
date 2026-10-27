import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: process.env.CREATOR_STUDIO_OUT_DIR || '../owner_panel/creator-studio',
    emptyOutDir: true,
    sourcemap: false,
    rollupOptions: {
      maxParallelFileOps: 128,
    },
  },
});
