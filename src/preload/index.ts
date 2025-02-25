import { contextBridge } from "electron";
import torrent from "@/backend/torrent/api";
import type { IpcResult } from "@/common/types";
import { electronAPI } from "@electron-toolkit/preload";

export async function invokeIpc<T>(channel: string, ...args: any): Promise<T> {
  const { error, result }: IpcResult<T> = await electronAPI.ipcRenderer.invoke(channel, ...args);
  if (error !== undefined) throw new Error(error);
  return result;
}
// Custom APIs for renderer
const api = {
  torrent
};

// Use `contextBridge` APIs to expose APIs to
// renderer only if context isolation is enabled, otherwise
// just add to the DOM global.
if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld("api", api);
  } catch (error) {
    console.error(error);
  }
} else {
  window.api = api;
}
