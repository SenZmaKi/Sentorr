import type { ConfigManager } from "@/backend/config/types";
import { ipcRenderer, ipcMain } from "electron";
import { jsonStringify, tryCatchAsync } from "./functions";
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
      console.log(`Handling ipc invocation: ${channel}()`, jsonStringify(args));
      const result = await tryCatchAsync(listener(...args));
      console.log(`Ipc handle result: ${channel}()`, jsonStringify(result));
      return result;
    },
  );
}

export async function invoke<Channel extends keyof IpcRendererEvent>(
  channel: Channel,
  ...args: Parameters<IpcRendererEvent[Channel]>
) {
  console.log(`Invoking ipc: ${channel}()`, jsonStringify(args));
  const result: Result<ReturnType<IpcRendererEvent[Channel]>> =
    await ipcRenderer.invoke(channel, ...args);
  console.log(`Ipc invocation result: ${channel}()`, jsonStringify(result));
  const [success, invokeError] = result;
  if (invokeError) {
    console.error(
      `Ipc invocation error: ${channel}()`,
      jsonStringify(invokeError),
    );
    throw new Error(invokeError.message);
  }
  return success;
}
