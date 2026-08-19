import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),

    VitePWA({
      registerType: "autoUpdate",

      manifest: {
        name: "HIBEYA Akal Budi",
        short_name: "Akal Budi",

        description:
          "Membina Akal. Menyemai Budi. Interactive learning for children.",

        theme_color: "#f7f4ed",
        background_color: "#f7f4ed",

        display: "standalone",
        start_url: "/",

        icons: []
      },

      workbox: {
        globPatterns: [
          "**/*.{js,css,html,svg,png,jpg,jpeg,webp,woff,woff2}"
        ]
      }
    })
  ]
});
