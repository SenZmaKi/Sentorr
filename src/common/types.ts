import type { TorrentServerApi } from "@/backend/torrent/server";
import type { IpcMain, IpcRenderer, IpcMainInvokeEvent } from "electron";

export class InvalidStateError extends Error {
  constructor(message: string) {
    super(`Invalid state: ${message}`);
  }
}

type IpcRendererEvent = TorrentServerApi;

export interface TypedIpcMain extends IpcMain {
  handle<Channel extends keyof IpcRendererEvent>(
    channel: Channel,
    listener: (
      event: IpcMainInvokeEvent,
      ...args: Parameters<IpcRendererEvent[Channel]>
    ) => ReturnType<IpcRendererEvent[Channel]>
  ): void;
}

export interface TypedIpcRenderer extends IpcRenderer {
  invoke<Channel extends keyof IpcRendererEvent>(
    channel: Channel,
    ...args: Parameters<IpcRendererEvent[Channel]>
  ): ReturnType<IpcRendererEvent[Channel]>;
}
