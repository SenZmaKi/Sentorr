import type { TorrentStream, TorrentFile } from "./common/types";
import type { Episode, Media } from "$backend/imdb/types";
import { getTorrentsFiles as getMovieTorrents } from "./yts/api";
import { getSeriesTorrents } from "./rargb/api";
import { parseSeason } from "./common/functions";
import { filterMap } from "@/common/functions";
const VIDEO_EXTS = ['3g2', '3gp', 'asf', 'avi', 'dv', 'flv', 'gxf', 'm2ts', 'm4a', 'm4b', 'm4p', 'm4r', 'm4v', 'mkv', 'mov', 'mp4', 'mpd', 'mpeg', 'mpg', 'mxf', 'nut', 'ogm', 'ogv', 'swf', 'ts', 'vob', 'webm', 'wmv', 'wtv']
const VIDEO_RX = new RegExp(`.(${VIDEO_EXTS.join('|')})$`, 'i')

export async function getTorrentFiles(media: Media, episode?: Episode) {
    if (!episode) return getMovieTorrents(media.id);
    if (!media.title) throw new Error("Media title is required");
    const [seasonFiles, episodeFiles] = await Promise.all([
        getSeriesTorrents(media.title, episode.seasonNumber, undefined),
        getSeriesTorrents(media.title, episode.seasonNumber, episode.number)
    ])
    console.log("seasonFiles", seasonFiles)
    return [...seasonFiles, ...episodeFiles];
}


export async function getTorrentsStreams(torrentFile: TorrentFile): Promise<TorrentStream[]> {
    return new Promise(async (resolve, reject) => {
        const magnetURI = torrentFile.torrentID;
        window.electron.ipcRenderer.send("get-torrent-streams", magnetURI);
        window.electron.ipcRenderer.on("torrent-streams-timeout-error", (_, message: string) => {
            reject(new Error(message))
        });
        window.electron.ipcRenderer.on("torrent-streams", (_, torrentStreams: TorrentStream[]) => {
            console.log("torrentStreams", torrentStreams)
            const videoStreams = torrentStreams.filter(({ filename }) =>
                VIDEO_RX.test(filename) && !filename.toLowerCase().includes("sample")
            );
            console.log("videoStreams", videoStreams)
            if (!videoStreams.length) return reject(new Error("No video files found"));
            if (!torrentFile.isCompleteSeason) {
                const url = videoStreams[0].url;
                const filename = videoStreams[0].filename;
                return resolve([{
                    filename,
                    url,
                }])
            }
            return resolve(filterMap(videoStreams, (stream) => {
                const streamSeason = parseSeason(stream.filename, "torrentStream")
                const fileSeason = parseSeason(torrentFile.filename as string, "torrentFile")
                const seasonNumber = streamSeason?.seasonNumber || fileSeason?.seasonNumber;
                if (!seasonNumber) {
                    console.warn("Failed to parse season number")
                    return undefined;
                }
                const episodeNumber = streamSeason?.episodeNumber || fileSeason?.episodeNumber;
                if (!episodeNumber) {
                    console.warn("Failed to parse episode number")
                    return undefined;
                }
                const url = stream.url
                const filename = stream.filename;
                return {
                    filename,
                    url,
                    info: {
                        seasonNumber,
                        episodeNumber
                    }

                }
            })
            )
        }
        )
    })

}

// const magnetLink = "magnet:?xt=urn:btih:ACCD778E8EF86005A9B3E8B9407675862E306A90&dn=Mr+Robot+Season+2+Complete+720p+WEB-DL+EN-SUB+x264-%5BMULVAcoded%5D+S02&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A80&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=http%3A%2F%2Fpow7.com%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fp4p.arenabg.com%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2F9.rarbg.com%3A2710%2Fannounce&tr=udp%3A%2F%2Finferno.demonoid.pw%3A3393%2Fannounce&tr=udp%3A%2F%2Ftracker.ex.ua%3A80%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2710%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce"
// Client.add(magnetLink, torrent => {
//     torrent.files.forEach(file => {
//         console.log("name", file.name)
//         console.log("stream url", file.streamURL)
//     })
// })
