import { CLIENT } from "@/common/constants";
import type { TorrentJson } from "./jsonTypes";
import { filterMap } from "@/common/functions";
import { validateTorrent } from "../common/functions";
import type { GetTorrentFilesParams, TorrentFile } from "../common/types";

const API_ENTRYPOINT = "https://apibay.org/q.php?";

export async function getTorrentFiles({
  seasonFormattedTitle,
  title,
  getCompleteSeason,
  isTvSeries,
  languages,
  mediaImdbID,
  episodeImdbID,
}: GetTorrentFilesParams & {
  mediaImdbID: string;
  episodeImdbID?: string;
}) {
  const url = `${API_ENTRYPOINT}q=${seasonFormattedTitle}`;
  const response = await CLIENT.get(url);
  const torrents: TorrentJson[] = await response.json();
  return filterMap(torrents, (torrent): TorrentFile | undefined => {
    const category = parseInt(torrent.category);
    // Categories around 500 seem to be mostly p0rn to be specific I only noticed
    // 501, 505, 506, 507 but we just ignore anything over 500 just incase
    if (category > 500) return undefined;
    // NOTE: The !!torrent.imdb is to handle a speculative edge case where they don't set in their response torrent.imdb
    // so if episodeImdbID is undefined the second condition is true, I am yet to experience it but it could be annoying
    // to debug incase it ever happens
    const ignoreTitle =
      !!torrent.imdb &&
      (torrent.imdb === episodeImdbID || torrent.imdb === mediaImdbID);
    const result = validateTorrent(
      title,
      torrent.name,
      isTvSeries,
      getCompleteSeason,
      languages,
      ignoreTitle,
    );
    if (!result) return undefined;
    const { resolution } = result;
    const sizeBytes = parseInt(torrent.size);
    const size = prettyFormatBytes(sizeBytes);
    const seeders = parseInt(torrent.seeders);
    if (!seeders) return undefined;
    return {
      size,
      seeders,
      dateUploaded: torrent.added,
      torrentID: torrent.info_hash,
      resolution,
      isCompleteSeason: getCompleteSeason,
    };
  });
}
function prettyFormatBytes(bytes: number) {
  const bytes_in_kb = 1024;
  if (bytes < bytes_in_kb) return `${bytes} B`;
  if (bytes < bytes_in_kb * bytes_in_kb)
    return `${(bytes / bytes_in_kb).toFixed(2)} KB`;
  if (bytes < bytes_in_kb * bytes_in_kb * bytes_in_kb)
    return `${(bytes / (bytes_in_kb * bytes_in_kb)).toFixed(2)} MB`;
  return `${(bytes / (bytes_in_kb * bytes_in_kb * bytes_in_kb)).toFixed(2)} GB`;
}
