import path from "path";
import fs from "fs/promises";
import { client, server, readyState, config } from "./server";
import {
  type TorrentStream,
  SelectTorrentStreamError,
  GetTorrentStreamsError,
} from "./common/types";
import { jsonStringify, tryCatchAsync } from "@/common/functions";
import { onTorrentError, onTorrentWarning } from "./handlers";
import { type TorrentStreamStats } from "./common/types";
import WebTorrent from "webtorrent";
import { hasErrorMessage } from "./common/functions";
import { RecoverableErrorMessage } from "./common/constants";

function createGetTorrentStreamsLock() {
  let promise: Promise<void> | undefined = undefined;
  let resolvePromise: (() => void) | undefined = undefined;

  async function acquire() {
    while (promise) await promise;

    promise = new Promise<void>((resolve) => {
      resolvePromise = resolve;
    });
  }

  function release() {
    if (!resolvePromise) return;
    resolvePromise();
    promise = undefined;
    resolvePromise = undefined;
  }
  return {
    async withLock<T>(callback: () => Promise<T> | T): Promise<T> {
      await acquire();
      try {
        return await callback();
      } finally {
        release();
      }
    },
  };
}
const getTorrentStreamsLock = createGetTorrentStreamsLock();

const fileTorrentStreamQueue: {
  file: WebTorrent.TorrentFile;
  torrentStream: TorrentStream;
}[] = [];

function getCurrentTorrent() {
  if (!fileTorrentStreamQueue.length) return undefined;
  const currentFile = fileTorrentStreamQueue[0].file;
  const currentTorrent = client.torrents.find((t) =>
    t.files.includes(currentFile),
  );
  return currentTorrent;
}

function torrentToTorrentStreams(torrent: WebTorrent.Torrent): TorrentStream[] {
  return torrent.files.map((file) => {
    // Fix windows paths for url
    const streamURL = file.streamURL.replaceAll("\\", "/");
    const port = server.address().port;
    const url = `http://localhost:${port}${streamURL}`;
    const filepath = file.path;
    const filename = file.name;
    const magnetURI = torrent.magnetURI;
    return { filepath, url, magnetURI, filename };
  });
}

async function removeTorrent(torrentID: string) {
  return new Promise<void>(async (resolve, reject) => {
    await readyState.waitTillReady();
    await client.remove(torrentID, { destroyStore: true }, (error) => {
      if (error) {
        console.error(`Error removing torrent ${torrentID}: ${error}`);
        reject(error);
      } else {
        resolve();
      }
    });
  });
}

export async function getTorrent(torrentID: string) {
  const torrent = await client.get(torrentID);
  if (!torrent) return undefined;
  await waitForMetadata(torrent);
  return torrent;
}

function waitForMetadata(torrent: WebTorrent.Torrent) {
  return new Promise<void>(async (resolve) => {
    if (torrent.files.length) return resolve();
    torrent.once("metadata", () => {
      return resolve();
    });
  });
}

//  Most of the awkwardness here is to handle concurrent calls where torrentID is the same
async function getTorrentStreams(torrentID: string) {
  console.log("getTorrentStreams()", torrentID);
  await readyState.waitTillReady();

  return new Promise<TorrentStream[]>(async (resolve, reject) => {
    let success = false;

    function succeed(torrent: WebTorrent.Torrent) {
      const torrentStreams = torrentToTorrentStreams(torrent);
      console.log("getTorrentStreams() done", jsonStringify(torrentStreams[0]));
      success = true;
      client.removeListener("error", handleDuplicateError);
      resolve(torrentStreams);
    }

    async function handleDuplicateError(error: Error | string) {
      if (!hasErrorMessage(error, [RecoverableErrorMessage.DuplicateTorrent]))
        return;
      const torrent = await getTorrent(torrentID);
      if (!torrent) return;
      succeed(torrent);
    }

    client.on("error", handleDuplicateError);

    const maybeTorrent = await getTorrent(torrentID);
    if (maybeTorrent) succeed(maybeTorrent);
    client.add(
      torrentID,
      {
        deselect: true,
        destroyStoreOnDestroy: true,
      },
      async (torrent) => {
        await waitForMetadata(torrent);
        torrent.on("error", onTorrentError);
        torrent.on("warning", onTorrentWarning);
        succeed(torrent);
      },
    );

    setTimeout(async () => {
      if (success || !(await client.get(torrentID))) return;
      await removeTorrent(torrentID);
      console.error(`Torrent ${torrentID} timed out`);
      return reject(new Error(GetTorrentStreamsError.TorrentTimeout));
    }, config.torrentTimeoutSecs * 1000);
  });
}

async function selectTorrentStream(torrentStream: TorrentStream) {
  return new Promise<void>(async (resolve, reject) => {
    await readyState.waitTillReady();
    const queuedIndex = fileTorrentStreamQueue.findIndex(
      (f) =>
        f.torrentStream.filepath === torrentStream.filepath &&
        f.torrentStream.magnetURI === torrentStream.magnetURI,
    );
    if (queuedIndex !== -1) {
      console.log(
        `Torrent stream ${torrentStream.filepath} was already queued, removing it`,
      );
      fileTorrentStreamQueue.splice(queuedIndex, 1);
    }
    const torrent = client.torrents.find(
      (torrent) => torrent.magnetURI === torrentStream.magnetURI,
    );
    if (!torrent) return reject(SelectTorrentStreamError.StreamNotFound);
    const file = torrent.files.find((f) => f.path === torrentStream.filepath);
    if (!file)
      return reject(
        new Error(
          `Invalid state: File  "${torrentStream.filepath}" not found in torrent "${torrentStream.magnetURI}"`,
        ),
      );
    await deselectAllTorrentStreams();
    console.log(`Selecting torrent stream ${torrentStream.filepath}`);
    file.select();
    fileTorrentStreamQueue.push({ file, torrentStream });
    if (fileTorrentStreamQueue.length > config.maxTorrentStreams) {
      const first = fileTorrentStreamQueue.shift();
      if (!first)
        throw new Error("Invalid state: File torrent stream queue is empty");
      console.log("Queue size exceeded");
      const absoluteFilePath = path.join(torrent.path, first.file.path);
      console.log(`Deleting ${absoluteFilePath}`);
      const [, rmError] = await tryCatchAsync(fs.rm(absoluteFilePath));
      if (rmError)
        console.error(`Failed to delete file ${absoluteFilePath}`, rmError);
      if (
        !fileTorrentStreamQueue.find(
          ({ torrentStream }) =>
            torrentStream.magnetURI === first.torrentStream.magnetURI,
        )
      ) {
        console.log(
          `Torrent ${first.torrentStream.magnetURI} has no files in queue referencing it, removing it`,
        );
        await removeTorrent(first.torrentStream.magnetURI);
      }
    }
    resolve();
  });
}

async function clearTorrents() {
  await readyState.waitTillReady();
  await Promise.all(client.torrents.map((t) => removeTorrent(t.magnetURI)));
  fileTorrentStreamQueue.length = 0;
}

async function deselectAllTorrentStreams() {
  console.log("deselectAllTorrentStreams()");
  await readyState.waitTillReady();
  fileTorrentStreamQueue.forEach((f) => f.file.deselect());
  console.log("deselectAllTorrentStreams() done");
}

async function getCurrentTorrentStreamStats(): Promise<
  TorrentStreamStats | undefined
> {
  await readyState.waitTillReady();
  const torrent = getCurrentTorrent();
  if (!torrent) return undefined;
  const { downloadSpeed, uploadSpeed, numPeers } = torrent;
  return {
    downloadSpeed,
    uploadSpeed,
    numPeers,
  };
}
const torrentManager = {
  getTorrentStreams,
  selectTorrentStream,
  clearTorrents,
  deselectAllTorrentStreams,
  getCurrentTorrentStreamStats,
};

export default torrentManager;
