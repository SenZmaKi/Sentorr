import { contextBridge } from "electron";
import torrent from "@/backend/torrent/ipc";
import config from "@/backend/config/ipc";
import { tryCatch } from "@/common/functions";

const ipc = { torrent, config };
export type Ipc = typeof ipc;

const [, exposeError] = tryCatch(() =>
  contextBridge.exposeInMainWorld("ipc", ipc),
);
if (exposeError)
  console.error(`Failed to expose "ipc" in main world:`, exposeError);
