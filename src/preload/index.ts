import { contextBridge } from "electron";
import torrent from "@/backend/torrent/api";
import type { IpcResult } from "@/common/types";
import { electronAPI } from "@electron-toolkit/preload";

export async function invokeIpc<T>(channel: string, ...args: any): Promise<T> {
  const { error, result }: IpcResult<T> = await electronAPI.ipcRenderer.invoke(
    channel,
    ...args,
  );
  if (error !== undefined) throw new Error(error);
  return result;
}
const ipc = {
  torrent,
};

try {
  contextBridge.exposeInMainWorld("ipc", ipc);
} catch (error) {
  console.error(error);
}