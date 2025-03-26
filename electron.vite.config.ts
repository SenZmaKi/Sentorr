import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";

const alias = [
  {
    find: "@",
    replacement: fileURLToPath(new URL("./src/", import.meta.url)),
  },
];
export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias,
    },
    root: ".",
    build: {
      rollupOptions: {
        input: {
          index: fileURLToPath(new URL("./src/main/index.ts", import.meta.url)),
          worker: fileURLToPath(
            new URL("./src/backend/torrent/server/worker.ts", import.meta.url),
          ),
        },
      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias,
    },
  },
  renderer: {
    plugins: [svelte()],
    resolve: {
      alias,
    },
  },
});
