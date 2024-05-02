export type EpisodesResultsJson = {
  data: {
    title: {
      episodes: {
        episodes: {
          total: number;
          pageInfo: {
            hasNextPage: boolean;
            endCursor: string;
            __typename: string;
          };
          edges: Array<{
            node: {
              id: string;
              titleText: {
                text: string;
                __typename: string;
              };
              titleType: {
                id: string;
                __typename: string;
              };
              plot:
                | {
                    plotText: {
                      plaidHtml: string;
                      __typename: string;
                    };
                    __typename: string;
                  }
                | undefined;
              releaseDate: {
                month: number;
                day: number;
                year: number;
                __typename: string;
              };
              canRate: {
                isRatable: boolean;
                __typename: string;
              };
              ratingsSummary: {
                aggregateRating: number;
                voteCount: number;
                __typename: string;
              };
              series: {
                displayableEpisodeNumber: {
                  episodeNumber: {
                    id: string;
                    displayableProperty: {
                      value: {
                        plainText: string;
                        __typename: string;
                      };
                      __typename: string;
                    };
                    __typename: string;
                  };
                  displayableSeason: {
                    id: string;
                    displayableProperty: {
                      value: {
                        plainText: string;
                        __typename: string;
                      };
                      __typename: string;
                    };
                    __typename: string;
                  };
                  __typename: string;
                };
                __typename: string;
              };
              primaryImage: {
                url: string;
                height: number;
                width: number;
                caption: {
                  plainText: string;
                  __typename: string;
                };
                __typename: string;
              };
              imageUploadLink: {
                url: string;
                __typename: string;
              };
              __typename: string;
            };
            __typename: string;
          }>;
          __typename: string;
        };
        __typename: string;
      };
      __typename: string;
    };
  };
  extensions: {
    disclaimer: string;
    experimentalFields: {
      janet: Array<any>;
      markdown: Array<any>;
      ratings: Array<any>;
      kahlo: Array<any>;
    };
  };
};

export type Episode = {
  id: string;
  title: string;
  number: number;
  seasonNumber: number;
  imageUrl: string;
  plot?: string;
  releaseDate: string;
  rating: number;
  ratingCount: number;
};

export type BaseResult = {
  id: string;
  title?: string;
  type?: string;
  imageUrl?: string;
  plot?: string;
  releaseYear?: number;
  endYear?: number | null;
  rating?: number | null;
  ratingCount?: number;
  genres?: string[];
  /**
   * In seconds
   */
  runtime?: number;
};

export type BaseNode = {
  id: string;
  titleText?: {
    text: string;
    __typename: string;
  };
  titleType: {
    id: string;
    text: string;
    canHaveEpisodes: boolean;
    displayableProperty: {
      value: {
        plainText: string;
        __typename: string;
      };
      __typename: string;
    };
    __typename: string;
  };
  originalTitleText: {
    text: string;
    __typename: string;
  };
  primaryImage: {
    id: string;
    width: number;
    height: number;
    url: string;
    caption: {
      plainText: string;
      __typename: string;
    };
    __typename: string;
  };
  plot?: {
    plotText?: {
      plainText: string;
    };
  };
  releaseYear: {
    year: number;
    endYear?: number;
    __typename: string;
  };
  __typename: string;
  ratingsSummary: {
    aggregateRating: number;
    voteCount: number;
    __typename: string;
  };
  runtime?: {
    seconds: number;
    __typename: string;
  };
  certificate?: {
    rating: string;
    __typename: string;
  };
  canRate: {
    isRatable: boolean;
    __typename: string;
  };
  titleGenres?: {
    genres?: Array<{
      genre: {
        text: string;
        __typename: string;
      };
      __typename: string;
    }>;
    __typename: string;
  };
  canHaveEpisodes: boolean;
  primaryWatchOption?: {
    additionalWatchOptionsCount: number;
    __typename: string;
  };
};

export type FanFavoritesResultJson = {
  data: {
    fanPicksTitles: {
      edges: Array<{
        node: BaseNode;
        __typename: string;
      }>;
      __typename: string;
    };
  };
  extensions: {
    disclaimer: string;
    experimentalFields: {
      watch: Array<any>;
      ratings: Array<any>;
      video: Array<any>;
      janet: Array<any>;
      markdown: Array<any>;
    };
  };
};

export type PopularTitlesJson = {
  data: {
    popularTitles: {
      titles: Array<BaseNode>;
      paginationToken: string;
      __typename: string;
    };
  };
  extensions: {
    disclaimer: string;
    experimentalFields: {
      search: Array<any>;
      ratings: Array<any>;
      watch: Array<any>;
      video: Array<any>;
      janet: Array<any>;
      markdown: Array<any>;
    };
  };
};

export type Media = {
  id: string;
  title?: string;
  type?: MediaType;
  imageUrl?: string;
  bannerImageUrl?: string;
  trailerUrl?: string;
  plot?: string;
  genres?: Genre[];
  releaseYear?: number;
  endYear?: number;
  rating?: number;
  ratingCount?: number;
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
  isMovie: boolean;
  isOngoing: boolean;
};

export type MediaMetadataJson = {
  "@context": string;
  "@type": string;
  url: string;
  name: string;
  image: string;
  description: string;
  review: {
    "@type": string;
    itemReviewed: {
      "@type": string;
      url: string;
    };
    author: {
      "@type": string;
      name: string;
    };
    dateCreated: string;
    inLanguage: string;
    name: string;
    reviewBody: string;
  };
  aggregateRating: {
    "@type": string;
    ratingCount: number;
    bestRating: number;
    worstRating: number;
    ratingValue: number;
  };
  contentRating: string;
  genre: Array<string>;
  datePublished: string;
  keywords: string;
  trailer?: {
    "@type": string;
    name: string;
    embedUrl: string;
    thumbnail: {
      "@type": string;
      contentUrl: string;
    };
    thumbnailUrl: string;
    url: string;
    description: string;
    duration: string;
    uploadDate: string;
  };
  actor?: Array<{
    "@type": string;
    url: string;
    name: string;
  }>;
  director?: Array<{
    "@type": string;
    url: string;
    name: string;
  }>;
  creator?: Array<{
    "@type": string;
    url: string;
    name?: string;
  }>;
  duration: string;
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
  next: (() => Promise<Pagination<T>>) | undefined;
};

export type Actor = {
  name: string;
  character?: string;
  imageUrl?: string;
};

export type AdvancedTitleSearchResultJson = {
  data: {
    advancedTitleSearch: {
      total: number;
      pageInfo: {
        hasPreviousPage: boolean;
        hasNextPage: boolean;
        startCursor: string;
        endCursor: string;
        __typename: string;
      };
      edges: Array<{
        node: {
          title: BaseNode;
          __typename: string;
        };
        __typename: string;
      }>;
      __typename: string;
    };
  };
  extensions: {
    disclaimer: string;
    experimentalFields: {
      search: Array<any>;
      ratings: Array<any>;
      metacritic: Array<any>;
      video: Array<any>;
      janet: Array<any>;
      markdown: Array<any>;
    };
  };
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
  min?: number | string;
  max?: number | string;
};

export type ReleaseDateRange = {
  start?: string;
  end?: string;
};

export type SearchFilters = {
  pageKey?: string;
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
