import WebTorrent, { type NodeServer } from "webtorrent";
import { tryCatchAsync } from "@/common/functions";
import { onClientError, onClientInfo, onServerError } from "./handlers";
import { TorrentClientError, type TorrentServerConfig } from "./common/types";
import torrentManager from "./manager";
import { hasErrorCode } from "./common/functions";
import { InvalidStateError } from "@/common/types";

export let client: WebTorrent.Instance;
export let server: NodeServer;
export let readyState = createReadyState();
export let config: TorrentServerConfig;

/**
 * Create a new `client` and `server` using the provided `config` and start listening on the `server`
 */
export async function start(torrentConfig: TorrentServerConfig) {
  config = torrentConfig;
  client = new WebTorrent(torrentConfig);
  client.on("error", onClientError);
  client.on("info", onClientInfo);
  server = client.createServer({}, "node") as NodeServer;
  const [, listenError] = await tryCatchAsync(
    listen(server, client, torrentConfig.serverPort),
  );
  // Most likely client errored out and was destroyed
  if (listenError) {
    console.error(
      `Server Error listening on port ${torrentConfig.serverPort}`,
      listenError,
    );
    readyState.resolveReady(false);
    return;
  }
  server.server.on("error", onServerError);
  console.log(`Client torrentPort is: ${client.torrentPort}`);
  readyState.resolveReady(true);
}

async function close() {
  await readyState.waitTillReady();
  return new Promise<void>(async (resolve, reject) => {
    console.log("Closing server");
    server.close();
    console.log("Destroying client");
    client.destroy((error) => {
      if (error) {
        console.error(`Error destoying client: ${error}`);
        reject(error);
      } else {
        resolve();
      }
    });
  });
}

async function listen(
  server: NodeServer,
  client: WebTorrent.Instance,
  port: number,
) {
  server.listen(port);
  return new Promise<number>((resolve, reject) => {
    server.server.once("listening", () => {
      const finalPort = server.address().port;
      console.log(`Server listening on port ${finalPort}`);
      resolve(finalPort);
    });
    client.once("error", (error) =>
      reject(new Error("Client Error", { cause: error })),
    );
    server.server.once("error", (error) => {
      if (hasErrorCode(error, ["EADDRINUSE"])) {
        console.error(
          `Server port ${port} is already in use, retrying on any available port`,
        );
        server.listen();
      } else reject(error);
    });
  });
}

function createReadyState() {
  let resolveReady!: (isReady: boolean) => void;
  let readyPromise!: Promise<boolean>;
  notReady();

  function notReady() {
    readyPromise = new Promise<boolean>((resolve) => {
      resolveReady = resolve;
    });
  }

  async function waitTillReady() {
    let isReady = await readyPromise;
    if (isReady) return;
    if (!client.destroyed)
      // not isReady should only be reached if the client was destroyed by a fatal error
      throw new InvalidStateError(
        "not isReady and yet still not client.destroyed",
      );
    console.log(
      "Client is destroyed attempting to await for new client creation",
    );
    // `onClientError` will call `notReady()` then create a new `client` if the error that caused destroy is recoverable
    isReady = await readyPromise;
    if (isReady) return;
    if (!client.destroyed)
      // not isReady should only be reached if the client was destroyed by a fatal error
      throw new InvalidStateError(
        "not isReady and yet still not client.destroyed",
      );
    console.error(TorrentClientError.ClientIsDestroyed);
    throw new Error(TorrentClientError.ClientIsDestroyed);
  }

  return { readyPromise, waitTillReady, resolveReady, notReady };
}

const torrentServer = {
  start,
  close,
  ...torrentManager,
};
export default torrentServer;
