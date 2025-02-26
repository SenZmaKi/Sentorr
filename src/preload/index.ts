import { contextBridge } from "electron";
import torrent from "@/backend/torrent/api";

const ipc = { torrent };

try {
  contextBridge.exposeInMainWorld("ipc", ipc);
} catch (error) {
  console.error(`Failed to expose "ipc" in main world:`, error);
}
