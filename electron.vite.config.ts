import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
  },
  renderer: {
    plugins: [svelte()],
    resolve: {
      alias: [
        {
          find: "$backend",
          replacement: fileURLToPath(
            new URL("./src/backend/", import.meta.url),
          ),
        },
        {
          find: "$frontend",
          replacement: fileURLToPath(
            new URL("./src/renderer/", import.meta.url),
          ),
        },
        {
          find: "@",
          replacement: fileURLToPath(new URL("./src/", import.meta.url)),
        },
      ],
    },
  },
});
