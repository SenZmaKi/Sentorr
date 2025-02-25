import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { fileURLToPath, URL } from "url";

const alias = [{
  find: "@",
  replacement: fileURLToPath(new URL("./src/", import.meta.url)),
}];
export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias
    },
  },
  renderer: {
    plugins: [svelte()],
    resolve: {
      alias
    },
  },
});
