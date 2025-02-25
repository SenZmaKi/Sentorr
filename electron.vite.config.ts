import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";

const pathAlias = {
  find: "@",
  replacement: fileURLToPath(new URL("./src/", import.meta.url)),
};
export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: [
        pathAlias
      ],
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: [
        pathAlias
      ],
    },
  },
  renderer: {
    plugins: [svelte()],
    resolve: {
      alias: [
        pathAlias
      ],
    },
  },
});
