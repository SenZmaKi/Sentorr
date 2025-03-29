import App from "./App.svelte";
import "./index.css";

const target = document.getElementById("app");
if (!target) throw new Error("No app element found");
const app = new App({
  target,
});

export default app;
