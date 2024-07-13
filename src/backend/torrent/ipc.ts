
import WebTorrent, { type NodeServer } from "webtorrent";
import type { TorrentStream } from "./common/types";
import { TimeoutError } from "./error";
const Client = new WebTorrent();
const server = Client.createServer({},) as NodeServer;
// TODO: Ignore the specific error
// @ts-ignore
server.listen(0);
const PORT = server.address().port;




export async function getTorrentStreams(magnetURI: string): Promise<TorrentStream[]> {
    return new Promise((resolve, reject) => {
        let success = false;
        Client.add(magnetURI, torrent => {
            const torrentStreams = torrent.files.map(file => {
                const url = `http://localhost:${PORT}${file.streamURL}`;
                const filename = file.name;
                return { filename, url };
            });
            success = true;
            resolve(torrentStreams);
        });

        setTimeout(() => {
            if(success) return;
            Client.remove(magnetURI);
            reject(new TimeoutError());
        }, 20000);
    });

}
// const magnetLink = "magnet:?xt=urn:btih:ACCD778E8EF86005A9B3E8B9407675862E306A90&dn=Mr+Robot+Season+2+Complete+720p+WEB-DL+EN-SUB+x264-%5BMULVAcoded%5D+S02&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A80&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=http%3A%2F%2Fpow7.com%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fp4p.arenabg.com%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2F9.rarbg.com%3A2710%2Fannounce&tr=udp%3A%2F%2Finferno.demonoid.pw%3A3393%2Fannounce&tr=udp%3A%2F%2Ftracker.ex.ua%3A80%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2710%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce"
// Client.add(magnetLink, torrent => {
//     torrent.files.forEach(file => {
//         console.log("name", file.name)
//         console.log("stream url", file.streamURL)
//     })
// })