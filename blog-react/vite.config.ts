import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // Same /api prefix the nginx image forwards, so dev needs no CORS either.
    proxy: {
      "/api": { target: "http://localhost:8080", rewrite: (path) => path.replace(/^\/api/, "") },
    },
  },
});
