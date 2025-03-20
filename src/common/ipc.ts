import type { TorrentServer } from "@/backend/torrent/server";
import type { ConfigManager } from "@/backend/config/types";
import type { IpcMain, IpcRenderer, IpcMainInvokeEvent } from "electron";
import { ipcRenderer, ipcMain } from "electron";

type IpcRendererEvent = TorrentServer & ConfigManager;

export interface TypedIpcMain extends IpcMain {
  handle<Channel extends keyof IpcRendererEvent>(
    channel: Channel,
    listener: (
      event: IpcMainInvokeEvent,
      ...args: Parameters<IpcRendererEvent[Channel]>
    ) => ReturnType<IpcRendererEvent[Channel]>,
  ): void;
}

export interface TypedIpcRenderer extends IpcRenderer {
  invoke<Channel extends keyof IpcRendererEvent>(
    channel: Channel,
    ...args: Parameters<IpcRendererEvent[Channel]>
  ): ReturnType<IpcRendererEvent[Channel]>;
}

export const typedIpcMain = ipcMain as TypedIpcMain;
export const typedIpcRenderer = ipcRenderer as TypedIpcRenderer;
