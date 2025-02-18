
import WebTorrent, { type TorrentFile as WTTorrentFile } from "webtorrent";
import { type TorrentStream, TorrentStreamsError, TorrentStreamStats } from "./common/types";
import path from "path";
import fs from "fs/promises";
import readline from "readline";
import { exit } from "process";


const Client = new WebTorrent();
const Server = Client.createServer({});
// @ts-ignore
Server.listen(5000);
const PORT = Server.address().port;
const GET_TORRENT_STREAMS_TIMEOUT_MS = 2 * 10000;
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
            // @ts-ignore: Bad typings
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

async function test() {
    const magnetURI = "magnet:?xt=urn:btih:711EA7C37AEAA53B4B8511EC14C6B2DA477AF37B&dn=Mr.Robot.Season.1-4.S01-04.COMPLETE.1080p.BluRay.WEB.10bit.DD5.1&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.bittor.pw%3A1337%2Fannounce&tr=udp%3A%2F%2Fpublic.popcorn-tracker.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.dler.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969&tr=udp%3A%2F%2Fopen.demonii.com%3A1337%2Fannounce"
    const torrentStreams = await getTorrentStreams(magnetURI);
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    const waitForInput = () => new Promise(resolve => rl.question("Press enter  to continue", resolve));
    await waitForInput()
    const first = torrentStreams[0];
    console.log("first", first.url)
    await selectTorrentStream(first);
    await waitForInput()
    const second = torrentStreams[1];
    console.log("second", second.url)
    await selectTorrentStream(second);
    await waitForInput()
    await deselectAllTorrentStreams();
    await waitForInput();
    await closeTorrentStreamsServer();
    await waitForInput();
    exit(0);

}

// await test();
