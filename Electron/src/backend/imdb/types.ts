export type BaseMedia = {
  title?: string;
  imageUrl?: ScalableImageUrl;
  plot?: string;
  rating?: number;
  ratingCount?: number;
};
export type Episode = BaseMedia & {
  id: EpisodeId;
  seasonEpisode: SeasonEpisode;
  releaseDate?: ImdbDate;
};

export type SeasonEpisode = {
  seasonNumber: number;
  episodeNumber: number;
};
export type ImdbDate = {
  day?: number;
  month?: number;
  year?: number;
};

export type Media = BaseMedia & {
  id: MediaId;
  type?: MediaType;
  bannerImageUrl?: string;
  trailerUrl?: string;
  genres?: Genre[];
  releaseYear?: number;
  endYear?: number;
  popularityScore?: number;
  contentRating?: string;
  actors?: Actor[];
  directors?: string[];
  creators?: string[];
  runtime?: string;
  episodeCount?: number;
  seasonsCount?: number;
  productionStatus?: string;
  recommendations?: BaseResult[];
  canHaveEpisodes: boolean;
  isOngoing: boolean;
};

export type MediaId = string & { __brand: "MediaImdbId" };
export type EpisodeId = string & { __brand: "EpisodeImdbId" };
export type ScalableImageUrl = string & { __brand: "ScalableImageUrl" };

export type BaseResult = {
  id: MediaId;
  title?: string;
  type?: string;
  imageUrl?: ScalableImageUrl;
  plot?: string;
  releaseYear?: number;
  endYear?: number | null;
  rating?: number | null;
  ratingCount?: number;
  genres?: string[];
  canHaveEpisodes: boolean;
  /**
   * In seconds
   */
  runtime?: number;
};
export type Review = {
  title: string;
  author: string;
  rating?: number | undefined;
  content: string;
  date: string;
  likes: number;
  dislikes: number;
  hasSpoilers: boolean;
};

export type Pagination<T> = {
  results: T;
  nextPageKey?: string;
};

export type Actor = {
  name: string;
  character?: string;
  imageUrl?: string;
};

export enum Genre {
  Action = "Action",
  Adventure = "Adventure",
  Animation = "Animation",
  Biography = "Biography",
  Comedy = "Comedy",
  Crime = "Crime",
  Documentary = "Documentary",
  Drama = "Drama",
  Family = "Family",
  Fantasy = "Fantasy",
  FilmNoir = "Film-Noir",
  GameShow = "Game-Show",
  History = "History",
  Horror = "Horror",
  Music = "Music",
  Musical = "Musical",
  Mystery = "Mystery",
  News = "News",
  RealityTV = "Reality-TV",
  Romance = "Romance",
  SciFi = "Sci-Fi",
  Short = "Short",
  Sport = "Sport",
  TalkShow = "Talk-Show",
  Thriller = "Thriller",
  War = "War",
  Western = "Western",
}

export enum ApiMediaType {
  Movie = "movie",
  TVSeries = "tvSeries",
  Short = "short",
  TVMiniSeries = "tvMiniSeries",
  TVMovie = "tvMovie",
  TVSpecial = "tvSpecial",
  TVShort = "tvShort",
  Documentary = "documentary",
}

export enum MediaType {
  Movie = "Movie",
  TVSeries = "TV Series",
  Short = "Short",
  TVMiniSeries = "TV Mini Series",
  TVMovie = "TV Movie",
  TVSpecial = "TV Special",
  TVShort = "TV Short",
  Documentary = "Documentary",
}

export enum SortBy {
  POPULARITY = "POPULARITY",
  TITLE_REGIONAL = "TITLE_REGIONAL",
  USER_RATING = "USER_RATING",
  USER_RATING_COUNT = "USER_RATING_COUNT",
  BOX_OFFICE_GROSS_DOMESTIC = "BOX_OFFICE_GROSS_DOMESTIC",
  RUNTIME = "RUNTIME",
  YEAR = "YEAR",
  RELEASE_DATE = "RELEASE_DATE",
}

export enum SortOrder {
  ASC = "ASC",
  DESC = "DESC",
}
export type Range = {
  min?: number;
  max?: number;
};

export type ReleaseDateRange = {
  start?: string;
  end?: string;
};

export type SearchFilters = {
  searchTerm?: string;
  genres?: Genre[];
  mediaTypes?: MediaType[];
  sortBy?: SortBy;
  sortOrder?: SortOrder;
  ratingRange?: Range;
  ratingsCountRange?: Range;
  releaseDateRange?: ReleaseDateRange;
  runtimeRangeMinutes?: Range;
};
