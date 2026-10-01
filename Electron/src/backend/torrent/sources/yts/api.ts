import { netClient } from "@/common/constants";
import type { SearchResultsJson } from "./jsonTypes";
import type { YtsTorrentFile } from "../common/types";
import { parseResolution as vfpParseResolution } from "@ctrl/video-filename-parser";
import { parseResolution } from "../common/functions";
import { filterMap } from "@/common/functions";

const API_ENTRY_POINT = "https://yts.mx/api/v2";

export async function getTorrentsFiles(
  imdbMovieID: string,
): Promise<YtsTorrentFile[]> {
  const url = `${API_ENTRY_POINT}/list_movies.json?query_term=${imdbMovieID}&limit=50`; // 50 is the max results limit
  const response = await netClient.get(url);
  const json = (await response.json()) as SearchResultsJson;
  const movies = json.data.movies;
  if (!movies) return [];
  const movie = movies.find((movie) => movie.imdb_code === imdbMovieID);
  if (!movie || !movie.torrents) return [];
  return filterMap(movie.torrents, (torrent) => {
    const { resolution: vfpResolution } = vfpParseResolution(torrent.quality);
    if (!vfpResolution) return undefined;
    const resolution = parseResolution(vfpResolution);
    const sizeBytes = torrent.size_bytes;
    const dateUploadedISO = new Date(torrent.date_uploaded).toISOString();
    return {
      filename: undefined,
      resolution,
      seeders: torrent.seeds,
      torrentID: torrent.url,
      isCompleteSeason: false,
      sizeBytes,
      dateUploadedISO,
    };
  });
}
