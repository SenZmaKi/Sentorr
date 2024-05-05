import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [svelte()],

  resolve: {
    alias: [
      {
        find: "$backend",
        replacement: fileURLToPath(new URL("./backend/", import.meta.url)),
      },
      {
        find: "$frontend",
        replacement: fileURLToPath(new URL("./", import.meta.url)),
      },
      {
        find: "@",
        replacement: fileURLToPath(new URL("./", import.meta.url)),
      },
    ],
  },
});
