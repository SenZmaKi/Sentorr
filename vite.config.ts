import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [svelte()],
  resolve: {
    alias: [
      {
        find: "$backend",
        replacement: fileURLToPath(new URL("./src/backend/", import.meta.url)),
      },
      {
        find: "$frontend",
        replacement: fileURLToPath(new URL("./", import.meta.url)),
      },
      {
        find: "@",
        replacement: fileURLToPath(new URL("./src/", import.meta.url)),
      },
    ],
  },
});
