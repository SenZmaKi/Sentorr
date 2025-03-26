import type { ConfigManager } from "@/backend/config/types";
import { ipcRenderer, ipcMain } from "electron";
import { tryCatchAsync } from "./functions";
import { type Result } from "./types";
import type { TorrentServer } from "@/backend/torrent/server/common/types";

type IpcRendererEvent = ConfigManager & TorrentServer;

export function handle<Channel extends keyof IpcRendererEvent>(
  channel: Channel,
  listener: (
    ...args: Parameters<IpcRendererEvent[Channel]>
  ) => Promise<Awaited<ReturnType<IpcRendererEvent[Channel]>>>,
): void {
  ipcMain.handle(
    channel,
    async (_, ...args: Parameters<IpcRendererEvent[Channel]>) => {
      console.log(`Handling ipc invocation: ${channel}()`, args);
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
    console.error(`Ipc invocation error: ${channel}()`, invokeError);
    throw new Error(invokeError.message);
  }
  return result;
}
