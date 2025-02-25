
import WebTorrent, { type TorrentFile as WTTorrentFile } from "webtorrent";
import { type TorrentStream, TorrentStreamsError, type TorrentStreamStats } from "./common/types";
import path from "path";
import fs from "fs/promises";


const Client = new WebTorrent();
const Server = Client.createServer({});
Server.listen(5000);
const PORT = Server.address().port;
const GET_TORRENT_STREAMS_TIMEOUT_MS = 2 * 10_000;
const MAX_QUEUE_SIZE = 5;
let fileTorrentStreamQueue: {
    file: WTTorrentFile;
    torrentStream: TorrentStream;
}[] = []

function getCurrentTorrent() {
    if (!fileTorrentStreamQueue.length) return undefined;
    const currentFile = fileTorrentStreamQueue[0].file;
    const currentTorrent = Client.torrents.find(t => t.files.includes(currentFile));
    return currentTorrent;

}

function torrentToTorrentStreams(torrent: WebTorrent.Torrent): TorrentStream[] {
    return torrent.files.map(file => {
        // Fix windows paths for url
        const streamURL = file.streamURL.replaceAll("\\", "/");
        const url = `http://localhost:${PORT}${streamURL}`;
        const filepath = file.path;
        const filename = file.name;
        const magnetURI = torrent.magnetURI;
        return { filepath, url, magnetURI, filename };
    });
}


async function removeTorrent(torrentID: string) {
    return new Promise<void>(async (resolve, reject) => {
        await Client.remove(torrentID, { destroyStore: true },
            (error) => {
                if (error) {
                    console.error(`Error removing torrent ${torrentID}: ${error}`)
                    reject(error);
                } else {
                    resolve();
                }
            });

    })


}

export async function getTorrentStreams(torrentID: string): Promise<TorrentStream[]> {
    return new Promise(async (resolve, reject) => {
        let success = false;
        const existingTorrent = await Client.get(torrentID);
        if (existingTorrent) {
            return resolve(torrentToTorrentStreams(existingTorrent))
        };
        Client.add(torrentID, {
            deselect: true,
            destroyStoreOnDestroy: true,
        }, torrent => {
            console.log(`Torrent ${torrentID} added`);
            success = true;
            const torrentStreams = torrentToTorrentStreams(torrent);
            return resolve(torrentStreams);
        });

        setTimeout(async () => {
            if (success || !await Client.get(torrentID)) return;
            await removeTorrent(torrentID);
            console.error(`Torrent ${torrentID} timed out`);
            return reject(new Error(TorrentStreamsError.TorrentTimeout));
        }, GET_TORRENT_STREAMS_TIMEOUT_MS);
    });

}


export async function selectTorrentStream(torrentStream: TorrentStream) {
    return new Promise<void>(async (resolve, reject) => {
        const queuedIndex = fileTorrentStreamQueue.findIndex(f =>
            f.torrentStream.filepath === torrentStream.filepath && f.torrentStream.magnetURI === torrentStream.magnetURI);
        if (queuedIndex !== -1) {
            console.log(`Torrent stream ${torrentStream.filepath} was already queued, removing it`);
            fileTorrentStreamQueue.splice(queuedIndex, 1);
        }
        const torrent = Client.torrents.find(torrent => torrent.magnetURI === torrentStream.magnetURI);
        if (!torrent) return reject(TorrentStreamsError.TorrentWasRemoved);
        const file = torrent.files.find(f => f.path === torrentStream.filepath);
        if (!file) return reject(new Error(`Invalid state: File  "${torrentStream.filepath}" not found in torrent "${torrentStream.magnetURI}"`));
        await deselectAllTorrentStreams();
        console.log(`Selecting torrent stream ${torrentStream.filepath}`);
        file.select();
        fileTorrentStreamQueue.push({ file, torrentStream })
        if (fileTorrentStreamQueue.length > MAX_QUEUE_SIZE) {
            const first = fileTorrentStreamQueue.shift();
            if (!first) throw new Error("Invalid state: File torrent stream queue is empty");
            console.log("Queue size exceeded")
            const absoluteFilePath = path.join(torrent.path, first.file.path);
            console.log(`Deleting ${absoluteFilePath}`);
            try {
                await fs.rm(absoluteFilePath);
            } catch (error: any) {
                console.error(`Failed to delete file ${absoluteFilePath}`, error);

            }
            if (!fileTorrentStreamQueue.find(({ torrentStream }) => torrentStream.magnetURI === first.torrentStream.magnetURI)) {
                console.log(`Torrent ${first.torrentStream.magnetURI} has no files in queue referencing it, removing it`);
                await removeTorrent(first.torrentStream.magnetURI);
            }
        }
        resolve();
    })

}

export async function closeTorrentStreamsServer() {
    return new Promise<void>(async (resolve, reject) => {
        console.log("Closing server");
        Server.close();
        console.log("Destroying client")
        Client.destroy((error) => {
            if (error) {
                console.error(`Error destoying client: ${error}`)
                reject(error);
            } else {
                resolve();
            }
        });
    })

}

export async function clearTorrents() {
    await Promise.all(Client.torrents.map(t => removeTorrent(t.magnetURI)));
    fileTorrentStreamQueue = [];

}

export async function deselectAllTorrentStreams() {
    console.log("Deselecting all torrent streams");
    fileTorrentStreamQueue.forEach(f => f.file.deselect());
}

export async function getCurrentTorrentStreamStats(): Promise<TorrentStreamStats | undefined> {
    const torrent = getCurrentTorrent();
    if (!torrent) return undefined;
    const { downloadSpeed, uploadSpeed, numPeers } = torrent;
    return {
        downloadSpeed, uploadSpeed, numPeers
    }

}
