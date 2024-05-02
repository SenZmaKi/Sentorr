import { CLIENT } from "@/common/constants";
import type { SearchResultsJson, Torrent } from "./types.js";

const API_ENTRY_POINT = "https://yts.mx/api/v2/";

async function getTorrents(imdbMovieID: string): Promise<Array<Torrent>> {
  const url = `${API_ENTRY_POINT}list_movies.json?query_term=${imdbMovieID}&limit=50`; // 50 is the max results limit
  const response = await CLIENT.get(url);
  const json = (await response.json()) as SearchResultsJson;
  const movies = json.data.movies;
  const movie = movies.find((movie) => movie.imdb_code === imdbMovieID);
  return movie ? movie.torrents : [];
}

export { getTorrents };
