import { isErrorCode } from "./common/functions";
import { config, readyState, start } from "./server";

export async function onClientError(error: Error | string) {
  console.error(`WebTorrent client error`, error);
  if (isErrorCode(error, "EADDRINUSE", "EACCES")) {
    // TODO: Handle this
    if (isErrorCode("EACCES")) return;
    readyState.notReady();
    console.error(
      `Torrent port ${config.serverPort} is already in use, retrying on any available port`,
    );
    await start({ ...config, torrentPort: 0 });
    return;
  }
  throw error;
}

export function onServerError(error: Error | string) {
  console.error(`WebTorrent server error`, error);
  throw error;
}

export function onTorrentError(error: Error | string) {
  console.error(`WebTorrent torrent error`, error);
  throw error;
}

export function onTorrentWarning(warning: Error | string) {
  console.warn(`WebTorrent torrent warning`, warning);
}

export function onClientInfo(info: Error | string) {
  console.info(`WebTorrent client info`, info);
}
