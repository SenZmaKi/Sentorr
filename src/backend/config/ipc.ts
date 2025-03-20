import { typedIpcRenderer } from "@/common/ipc";
import type { Config } from "./types";

async function getConfig() {
  return typedIpcRenderer.invoke("getConfig");
}

async function setConfig(newConfig: Config) {
  return typedIpcRenderer.invoke("setConfig", newConfig);
}

const configManagerIpc = {
  getConfig,
  setConfig,
};

export type ConfigManagerIpc = typeof configManagerIpc;
export default configManagerIpc;
