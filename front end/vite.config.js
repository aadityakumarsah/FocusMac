import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
  preview: {
    port: 4173,
  },
  build: {
    // Keep demo video as a static public asset (not hashed) so
    // replacing public/demo-video.mov always updates the tour.
    assetsInlineLimit: 0,
  },
});
