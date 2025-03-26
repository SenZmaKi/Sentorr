import type { TorrentServer } from "@/backend/torrent/server/common/types";
import { type Worker, type MessagePort } from "worker_threads";
import { type Result } from "@/common/types";
import { tryCatchAsync } from "./functions";

type RendererPortEvent = TorrentServer;

type Message<Channel extends keyof RendererPortEvent> = {
  id: number;
  channel: Channel;
  args: Parameters<RendererPortEvent[Channel]>;
};

type Response<Channel extends keyof RendererPortEvent> = {
  id: number;
  channel: Channel;
  result: Result<Awaited<ReturnType<RendererPortEvent[Channel]>>>;
};

export function getHandleListenerGetter(worker: Worker) {
  return <Channel extends keyof RendererPortEvent>(channel: Channel) =>
    (...args: Parameters<RendererPortEvent[Channel]>) =>
      invoke(worker, channel, ...args);
}

function createInvoke() {
  let invokeId = 0;

  return function invoke<Channel extends keyof RendererPortEvent>(
    port: Worker,
    channel: Channel,
    ...args: Parameters<RendererPortEvent[Channel]>
  ): Promise<Awaited<ReturnType<RendererPortEvent[Channel]>>> {
    return new Promise<Awaited<ReturnType<RendererPortEvent[Channel]>>>(
      function (resolve, reject) {
        console.log(`Invoking port: ${channel}()`, args);
        const message: Message<Channel> = { channel, args, id: invokeId++ };

        function handleMessage(anyResponse: Response<keyof RendererPortEvent>) {
          if (anyResponse.id !== message.id) return;
          port.off("message", handleMessage);
          const response = anyResponse as Response<Channel>;
          console.log(`Port invocation response: ${channel}()`, response);
          const [success, invokeError] = response.result;
          if (invokeError) {
            console.error(`Port invocation error ${channel}():`, invokeError);
            return reject(invokeError);
          }
          resolve(success);
        }

        port.postMessage(message);
        port.on("message", handleMessage);
      },
    );
  };
}

const invoke = createInvoke();

export function getHandle(port: MessagePort) {
  return <Channel extends keyof RendererPortEvent>(
    channel: Channel,
    listener: (
      ...args: Parameters<RendererPortEvent[Channel]>
    ) => Promise<Awaited<ReturnType<RendererPortEvent[Channel]>>>,
  ) => handle(port, channel, listener);
}

function createHandle() {
  // TODO: Fix this type
  let channelToListener: Record<string, unknown> | undefined = undefined;
  async function handle<Channel extends keyof RendererPortEvent>(
    port: MessagePort,
    channel: Channel,
    listener: (
      ...args: Parameters<RendererPortEvent[Channel]>
    ) => Promise<Awaited<ReturnType<RendererPortEvent[Channel]>>>,
  ) {
    if (channelToListener) {
      channelToListener[channel] = listener;
      return;
    }
    channelToListener = {};
    channelToListener[channel] = listener;
    port.on("message", async (message: Message<Channel>) => {
      const { args, id, channel } = message;
      console.log(`Handling port invocation: ${channel}()`, args);
      const listener = channelToListener![channel] as any;
      const result = await tryCatchAsync(listener(...args));
      const anyResult = result as any;
      const response: Response<Channel> = { channel, id, result: anyResult };
      console.log(`Port handle response: ${channel}()`, response);
      port.postMessage(response);
    });
  }
  return handle;
}

/**
 * Mutltple bindings on the same channel will be ignored, only the last binding will be used.
 */
const handle = createHandle();
