import type { TorrentServer } from "@/backend/torrent/server";
import type { ConfigManager } from "@/backend/config/types";
import { ipcRenderer, ipcMain } from "electron";
import { tryCatchAsync, type Result } from "./functions";

type IpcRendererEvent = TorrentServer & ConfigManager;

export function handle<Channel extends keyof IpcRendererEvent>(
  channel: Channel,
  listener: (
    ...args: Parameters<IpcRendererEvent[Channel]>
  ) => Promise<Awaited<ReturnType<IpcRendererEvent[Channel]>>>,
): void {
  ipcMain.handle(
    channel,
    async (_, ...args: Parameters<IpcRendererEvent[Channel]>) => {
      return await tryCatchAsync(listener(...args));
    },
  );
}

export async function invoke<Channel extends keyof IpcRendererEvent>(
  channel: Channel,
  ...args: Parameters<IpcRendererEvent[Channel]>
) {
  console.log(`Invoking ipc: ${channel}()`, args);
  const [result, invokeError]: Result<ReturnType<IpcRendererEvent[Channel]>> =
    await ipcRenderer.invoke(channel, ...args);
  if (invokeError) {
    console.error(`Ipc invocation error: ${invokeError.message}`);
    throw new Error(invokeError.message);
  }
  return result;
}
