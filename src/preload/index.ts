import { contextBridge } from "electron";
// import torrent from "@/backend/torrent/ipc";
import torrentApi  from "@/backend/torrent/api";

import config from "@/backend/config/ipc";
import { tryCatch } from "@/common/functions";

const ipc = { torrent: torrentApi, config };
export type Ipc = typeof ipc;

if (process.contextIsolated) {
  const [, exposeError] = tryCatch(() =>
    contextBridge.exposeInMainWorld("ipc", ipc),
  );
  if (exposeError) {
    console.error(`Failed to expose "ipc" in main world:`, exposeError);
    throw exposeError;
  }
  // @ts-ignore define in d.ts
} else window.ipc = ipc;
