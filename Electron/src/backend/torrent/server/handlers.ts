// Nasty error handling cause of webtorrent's event based error handling gyaaaah
import {
  CLIENT_RECOVERABLE_ERROR_CODES,
  CLIENT_RECOVERABLE_ERROR_MESSSAGES,
  ClientRecoverableErrorCode,
  TORRENT_RECOVERABLE_ERROR_CODES,
} from "./common/constants";
import { hasErrorCode, hasErrorMessage } from "./common/functions";
import { client, config, readyState } from "./server";
import torrentServer from "./server";

export async function onClientError(error: Error | string) {
  console.error(`WebTorrent client error`, error);

  if (hasErrorCode(error, [ClientRecoverableErrorCode.EACCES])) {
    readyState.notReady();
    console.error(
      `Torrent port ${config.serverPort} is already in use, retrying on any available port`,
    );
    if (!client.destroyed) await torrentServer.close();
    await torrentServer.start({ ...config, torrentPort: 0 });
    return;
  }

  // TODO: Handle appropriate errors and confirm if all these don't destroy the client
  if (
    hasErrorCode(error, CLIENT_RECOVERABLE_ERROR_CODES) ||
    hasErrorMessage(error, CLIENT_RECOVERABLE_ERROR_MESSSAGES)
  )
    return;

  throw error;
}

export function onServerError(error: Error | string) {
  console.error(`WebTorrent server error`, error);
  throw error;
}

export function onTorrentError(error: Error | string) {
  console.error(`WebTorrent torrent error`, error);
  if (hasErrorCode(error, TORRENT_RECOVERABLE_ERROR_CODES)) return;
  throw error;
}

export function onTorrentWarning(warning: Error | string) {
  console.warn(`WebTorrent torrent warning`, warning);
}

export function onClientInfo(info: Error | string) {
  console.info(`WebTorrent client info`, info);
}
