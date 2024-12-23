import { CLIENT } from "@/common/constants.js";
import type { SearchResultsJson } from "./jsonTypes.js";
import type { TorrentFile } from "../common/types.js";
import { parseResolution } from "@ctrl/video-filename-parser";
import { filterMap } from "@/common/functions.js";

const API_ENTRY_POINT = "https://yts.mx/api/v2";

export async function getTorrentsFiles(imdbMovieID: string): Promise<TorrentFile[]> {
  const url = `${API_ENTRY_POINT}/list_movies.json?query_term=${imdbMovieID}&limit=50`; // 50 is the max results limit
  const response = await CLIENT.get(url);
  const json = (await response.json()) as SearchResultsJson;
  const movies = json.data.movies;
  if (!movies) return [];
  const movie = movies.find((movie) => movie.imdb_code === imdbMovieID);
  if (!movie || !movie.torrents) return [];
  return filterMap(movie.torrents, (torrent) => {
    const { resolution } = parseResolution(torrent.quality);
    if (!resolution) return undefined;
    const size = torrent.size;
    const dateUploaded = torrent.date_uploaded;
    return {
      resolution,
      seeders: torrent.seeds,
      torrentID: torrent.url,
      isCompleteSeason: false,
      size,
      dateUploaded,
    };
  });
}
