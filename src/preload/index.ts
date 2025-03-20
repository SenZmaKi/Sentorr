import { contextBridge } from "electron";
import torrent from "@/backend/torrent/ipc";
import config from "@/backend/config/ipc";

const ipc = { torrent, config };
export type Ipc = typeof ipc;

try {
  contextBridge.exposeInMainWorld("ipc", ipc);
} catch (error) {
  console.error(`Failed to expose "ipc" in main world:`, error);
}
