import { MediaType } from "$backend/imdb/types";

export const formattedMediaTypesMap = {
  Movie: MediaType.Movie,
  "TV Series": MediaType.TVSeries,
  Short: MediaType.Short,
  "TV Mini Series": MediaType.TVMiniSeries,
  "TV Movie": MediaType.TVMovie,
  "TV Special": MediaType.TVSpecial,
  "TV Short": MediaType.TVShort,
  Documentary: MediaType.Documentary,
} as const;

export const formattedMediaTypes = Object.keys(formattedMediaTypesMap);

