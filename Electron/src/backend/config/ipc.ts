import { invoke } from "@/common/ipc";
import type { Config } from "./types";

async function getConfig() {
  return await invoke("getConfig");
}

async function setConfig(newConfig: Config) {
  return await invoke("setConfig", newConfig);
}

const configManagerIpc = {
  getConfig,
  setConfig,
};

export type ConfigManagerIpc = typeof configManagerIpc;
export default configManagerIpc;
