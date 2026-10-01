import { contextBridge } from "electron";
// import torrent from "@/backend/torrent/ipc";
import torrentServer from "@/backend/torrent/ipc";

import config from "@/backend/config/ipc";
import { tryCatch } from "@/common/functions";

const ipc = { torrentServer, config };
export type Ipc = typeof ipc;

if (process.contextIsolated) {
  const [, exposeError] = tryCatch(() =>
    contextBridge.exposeInMainWorld("ipc", ipc),
  );
  if (exposeError) {
    console.error(`Failed to expose ipc in main world:`, exposeError);
    throw exposeError;
  }
} else window.ipc = ipc;
