import {
  SortBy,
  SortOrder,
  MediaType,
  type SearchFilters,
  type Genre,
  type BaseResult,
  type Episode,
  type Media,
  type Pagination,
  type Review,
  type ScalableImageUrl,
  type MediaId,
  type EpisodeId,
  type BaseMedia,
} from "./types";
import {
  type AdvancedTitleSearchResultJson,
  type BaseNode,
  type EpisodesResultJson,
  type FanFavoritesResultJson,
  type MediaMetadataJson,
  type PopularTitlesResultJson,
  type MoreMetadataJson,
  type ReviewsResultJson,
} from "./jsonTypes";
import {
  DEFAULT_RESULTS_LIMIT,
  MEDIA_TYPE_MAP,
  REVIEWS_HASH,
} from "./constants";
import { filterMap, parseHtml } from "@/common/functions";
import { DEBUG, netClient } from "@/common/constants";
import { DEFAULT_SORT_BY, DEFAULT_SORT_ORDER } from "./constants";
import {
  HOME_URL,
  DATE_STR,
  FAN_FAVORITES_HASH,
  ADVANCED_TITLE_SEARCH_HASH,
  EPISODES_HASH,
  POPULAR_TITLES_HASH,
  API_ENTRY_POINT,
  DEFAULT_RECOMMENDATIONS_VARIABLES,
  DEFAULT_LOCALE,
  DEFAULT_EPISODES_RESULTS_LIMIT,
} from "./constants";

export function makeScaledImageUrl(
  width: number,
  height: number,
  url: ScalableImageUrl,
  quality?: number,
): string {
  const split = url.split(".");
  const ext = split.pop();
  // Get a larger image for better quality, otherwise the images look ass
  quality = quality ?? 2;
  // The original url has high res images and they have really large sizes
  // if we use them we waste bandwidth and run into image rendering issues
  // cause browsers especially Chrome suck at rendering many high res large file
  // size images
  const scaledUrl = `${split.join(".")}QL75_UX${width * quality}_UY${height * quality}_.${ext}`;
  return scaledUrl;
}

export const getSessionCookies = (function () {
  let sessionCookies: string[] | undefined = undefined;
  return async function () {
    if (!sessionCookies) {
      const response = await netClient.get(HOME_URL);
      sessionCookies = response.headers.getSetCookie();
      return sessionCookies;
    }
    return sessionCookies;
  };
})();

function stringifyAndEncodeJson(json: any): string {
  return encodeURIComponent(JSON.stringify(json));
}
function generateAPIURL(
  operationName: string,
  variables: any,
  sha256Hash: string,
): string {
  const extensions = { persistedQuery: { sha256Hash, version: 1 } };
  const url = `${API_ENTRY_POINT}${operationName}&variables=${stringifyAndEncodeJson(
    variables,
  )}&extensions=${stringifyAndEncodeJson(extensions)}`;
  return url;
}

async function apiGet(
  url: string,
  headers: HeadersInit | undefined = undefined,
  cookies: string[] = [],
): Promise<any> {
  headers = { ...headers, ...{ "Content-Type": "application/json" } };
  const response = await netClient.get(url, headers, cookies);
  const resp_json = await response.json();
  if (DEBUG) {
    // console.log(
    //   `Url: ${url}\nStatus Code: ${response.status}\nJson:\n${JSON.stringify(resp_json, undefined, 4)}`,
    // );
    console.log(`IMDB Api Call Made: ${url}`);
  }
  return resp_json;
}

function buildBaseResult(node: BaseNode): BaseResult {
  const id = node.id as MediaId;
  const title = node.titleText?.text;
  const rating = node.ratingsSummary?.aggregateRating;
  const ratingCount = node.ratingsSummary?.voteCount;
  const type =
    node.titleType?.displayableProperty?.value?.plainText ||
    node.titleType?.text;
  const url = node.primaryImage?.url;
  const imageUrl = (url as ScalableImageUrl) || undefined;
  const plot = node.plot?.plotText?.plainText;
  const releaseYear = node.releaseYear?.year;
  const endYear = node.releaseYear?.endYear;
  const runtime = node.runtime?.seconds;
  const genres = node.titleGenres?.genres?.map((g) => g.genre.text);
  const isMovie = !node.canHaveEpisodes;
  return {
    id,
    title,
    type,
    imageUrl,
    plot,
    genres,
    runtime,
    releaseYear,
    endYear,
    rating,
    ratingCount,
    isMovie,
  };
}
// On IMDB the popularity is more akin to trending cause the popular media frequently change and are usually recently released media
export async function getTop10Trending(): Promise<BaseResult[]> {
  const page = await search({
    sortBy: SortBy.POPULARITY,
    sortOrder: SortOrder.ASC,
  });
  return page.results.slice(0, 10);
}

export async function getTop10OfAllTime(): Promise<BaseResult[]> {
  const page = await search({});
  return page.results.slice(0, 10);
}

// NOTE: This seems to be the only request that needs the session cookies
export async function getFanFavorites(): Promise<BaseResult[]> {
  const variables = {
    first: DEFAULT_RESULTS_LIMIT,
    ...DEFAULT_RECOMMENDATIONS_VARIABLES,
    locale: "en-US",
  };
  const url = generateAPIURL("FanFavorites", variables, FAN_FAVORITES_HASH);
  const sessionCookies = await getSessionCookies();
  const fanFavoritesJson = (await apiGet(
    url,
    undefined,
    sessionCookies,
  )) as FanFavoritesResultJson;
  return fanFavoritesJson.data.fanPicksTitles.edges.map(({ node }) =>
    buildBaseResult(node),
  );
}

export async function getPopularTitles(): Promise<BaseResult[]> {
  const variables = {
    limit: DEFAULT_RESULTS_LIMIT,
    ...DEFAULT_RECOMMENDATIONS_VARIABLES,
    queryFilter: { releaseDateRange: { end: DATE_STR } },
  };
  const url = generateAPIURL("PopularTitles", variables, POPULAR_TITLES_HASH);
  const popularTitleJson = (await apiGet(url)) as PopularTitlesResultJson;
  return popularTitleJson.data.popularTitles.titles.map((node) =>
    buildBaseResult(node),
  );
}

export async function search(
  filters: SearchFilters,
  pageKey?: string,
): Promise<Pagination<BaseResult[]>> {
  const {
    searchTerm = "",
    genres = [],
    mediaTypes = [],
    sortBy = DEFAULT_SORT_BY,
    sortOrder = DEFAULT_SORT_ORDER,
    ratingRange = {},
    ratingsCountRange = {},
    releaseDateRange = {},
    runtimeRangeMinutes = {},
  } = filters;
  const variables = {
    ...DEFAULT_LOCALE,
    after: pageKey || "",
    first: DEFAULT_RESULTS_LIMIT,
    titleTextConstraint: { searchTerm },
    genreConstraint: { allGenreIds: genres },
    releaseDateConstraint: { releaseDateRange },
    runtimeConstraint: { runtimeRangeMinutes },
    sortBy,
    sortOrder,
    titleTypeConstraint: {
      anyTitleTypeIds: mediaTypes.map((mediaType) => MEDIA_TYPE_MAP[mediaType]),
      excludeTitleTypeIds: [
        "tvEpisode",
        "musicVideo",
        "podcastSeries",
        "podcastEpisode",
        "video",
        "videoGame",
      ],
    },
    userRatingsConstraint: {
      aggregateRatingRange: ratingRange,
      ratingsCountRange,
    },
  };
  const url = generateAPIURL(
    "AdvancedTitleSearch",
    variables,
    ADVANCED_TITLE_SEARCH_HASH,
  );
  const advancedTitleSearchResultJson = (await apiGet(
    url,
  )) as AdvancedTitleSearchResultJson;
  const results =
    advancedTitleSearchResultJson.data.advancedTitleSearch.edges.map(
      ({ node }) => buildBaseResult(node.title),
    );
  const pageInfo =
    advancedTitleSearchResultJson.data.advancedTitleSearch.pageInfo;
  const nextPageKey = pageInfo.hasNextPage ? pageInfo.endCursor : undefined;
  return { results, nextPageKey };
}

export async function getEpisodes(
  mediaID: string,
  seasonNumber: number,
  pageKey?: string,
): Promise<Pagination<Episode[]>> {
  const variables = {
    ...DEFAULT_LOCALE,
    returnUrl: `${HOME_URL}close_me`,
    originalTitleText: false,
    after: pageKey || "",
    const: mediaID,
    first: DEFAULT_EPISODES_RESULTS_LIMIT,
    filter: { includeSeasons: [seasonNumber.toString()] },
  };
  const url = generateAPIURL(
    "TitleEpisodesSubPagePagination",
    variables,
    EPISODES_HASH,
  );
  const episodesJson = (await apiGet(url)) as EpisodesResultJson;
  const results = episodesJson.data.title.episodes.episodes.edges.map(
    ({ node: ep }) => {
      const id = ep.id as EpisodeId;
      const title = ep.titleText.text;
      const episodeNumber = parseInt(
        ep.series.displayableEpisodeNumber.episodeNumber.displayableProperty
          .value.plainText,
      );
      const seasonEpisode = {
        seasonNumber,
        episodeNumber,
      };
      const imageUrl = (ep.primaryImage.url as ScalableImageUrl) || undefined;
      const plot = ep.plot?.plotText.plaidHtml;
      const releaseDate = ep.releaseDate && {
        day: ep.releaseDate.day,
        month: ep.releaseDate.month,
        year: ep.releaseDate.year,
      };
      const rating = ep.ratingsSummary.aggregateRating;
      const ratingCount = ep.ratingsSummary.voteCount;
      return {
        id,
        title,
        seasonEpisode,
        seasonNumber,
        imageUrl,
        plot,
        releaseDate,
        rating,
        ratingCount,
      };
    },
  );
  const pageInfo = episodesJson.data.title.episodes.episodes.pageInfo;
  const nextPageKey = pageInfo.hasNextPage ? pageInfo.endCursor : undefined;
  return { results, nextPageKey };
}
export async function getMedia(mediaID: MediaId) {
  return getMediaOrEpisode(mediaID, false);
}

export async function getEpisode(episodeID: EpisodeId) {
  return getMediaOrEpisode(episodeID, true);
}

async function getMediaOrEpisode(
  id: MediaId,
  isEpisode: boolean,
): Promise<Media>;
async function getMediaOrEpisode(
  id: EpisodeId,
  isEpisode: boolean,
): Promise<Episode>;
async function getMediaOrEpisode(
  id: MediaId | EpisodeId,
  isEpisode: boolean,
): Promise<Media | Episode> {
  const url = `${HOME_URL}title/${id}`;
  const response = await netClient.get(url);
  const page = await response.text();
  const $ = parseHtml(page);
  const ldJsonStr = $('script[type="application/ld+json"]').text();
  const metadataJson = JSON.parse(ldJsonStr) as MediaMetadataJson;
  const moreldJsonStr = $("script#\\__NEXT_DATA__").text();
  const moreMetadataJson = JSON.parse(moreldJsonStr) as MoreMetadataJson;

  return isEpisode
    ? combineEpisodeMetadata(metadataJson, moreMetadataJson)
    : combineMediaMetadata(metadataJson, moreMetadataJson);
}

function extractBaseMedia(metadataJson: MediaMetadataJson): BaseMedia {
  return {
    title: metadataJson.name,
    imageUrl: (metadataJson.image as ScalableImageUrl) || undefined,
    plot: metadataJson.description,
    rating: metadataJson.aggregateRating?.ratingValue,
    ratingCount: metadataJson.aggregateRating?.ratingCount,
  };
}

function combineMediaMetadata(
  metadataJson: MediaMetadataJson,
  moreMetadata: MoreMetadataJson,
): Media {
  const base = extractBaseMedia(metadataJson);
  const aboveTheFoldData = moreMetadata.props.pageProps.aboveTheFoldData;
  const mainColumnData = moreMetadata.props.pageProps.mainColumnData;

  return {
    ...base,
    id: aboveTheFoldData.id as MediaId,
    type: aboveTheFoldData.titleType?.text as MediaType | undefined,
    bannerImageUrl: metadataJson.trailer?.thumbnailUrl,
    trailerUrl: metadataJson.trailer?.embedUrl,
    genres: metadataJson.genre as Genre[] | undefined,
    releaseYear: aboveTheFoldData.releaseYear?.year,
    endYear: aboveTheFoldData.releaseYear?.endYear,
    popularityScore: aboveTheFoldData.meterRanking?.currentRank,
    contentRating: metadataJson.contentRating,
    actors: mainColumnData.cast.edges.map(({ node: actor }) => ({
      name: actor.name.nameText.text,
      imageUrl: actor.name.primaryImage?.url || undefined,
      character: actor.characters?.[0]?.name || undefined,
    })),
    directors: metadataJson.director?.map((d) => d.name),
    creators: filterMap(metadataJson.creator ?? [], (cr) => cr.name),
    runtime: aboveTheFoldData.runtime?.displayableProperty?.value?.plainText,
    episodeCount: mainColumnData?.episodes?.totalEpisodes?.total,
    seasonsCount: mainColumnData?.episodes?.seasons?.length,
    productionStatus:
      aboveTheFoldData.productionStatus?.currentProductionStage?.text,
    recommendations: mainColumnData.moreLikeThisTitles.edges.map(({ node }) =>
      buildBaseResult(node),
    ),
    isMovie:
      aboveTheFoldData.titleType?.text == MediaType.TVMovie ||
      aboveTheFoldData.titleType?.text == MediaType.Movie,
    isOngoing:
      aboveTheFoldData.titleType?.text !== MediaType.Movie &&
      !!aboveTheFoldData.releaseYear?.year &&
      !aboveTheFoldData.releaseYear?.endYear,
  };
}

function combineEpisodeMetadata(
  metadataJson: MediaMetadataJson,
  moreMetadata: MoreMetadataJson,
): Episode {
  const base = extractBaseMedia(metadataJson);
  const aboveTheFoldData = moreMetadata.props.pageProps.aboveTheFoldData;
  const episodeNumber = aboveTheFoldData.series?.episodeNumber;

  if (!episodeNumber) {
    throw new Error("Missing episode number information");
  }

  return {
    ...base,
    id: aboveTheFoldData.id as EpisodeId,
    seasonEpisode: {
      episodeNumber: episodeNumber.episodeNumber,
      seasonNumber: episodeNumber.seasonNumber,
    },
    releaseDate: aboveTheFoldData.releaseDate
      ? {
          day: aboveTheFoldData.releaseDate.day,
          month: aboveTheFoldData.releaseDate.month,
          year: aboveTheFoldData.releaseDate.year,
        }
      : undefined,
  };
}

export async function getReviews(
  mediaID: string,
  hideSpoilers: boolean,
  pageKey?: string,
): Promise<Pagination<Review[]>> {
  const variables = {
    ...DEFAULT_LOCALE,
    after: pageKey || "",
    first: DEFAULT_RESULTS_LIMIT,

    const: mediaID,
    filter: hideSpoilers
      ? {
          spoiler: "EXCLUDE",
        }
      : {},
    sort: {
      by: "HELPFULNESS_SCORE",
      order: "DESC",
    },
  };
  const url = generateAPIURL("TitleReviewsRefine", variables, REVIEWS_HASH);
  const reviewsJson: ReviewsResultJson = await apiGet(url);
  const results: Review[] = reviewsJson.data.title.reviews.edges.map(
    ({ node: review }) => {
      return {
        author: review.author.nickName,
        date: review.submissionDate,
        content: review.text.originalText.plaidHtml,
        title: review.summary.originalText,
        likes: review.helpfulness.upVotes,
        dislikes: review.helpfulness.downVotes,
        hasSpoilers: review.spoiler,
        rating: review.authorRating,
      };
    },
  );
  const pageInfo = reviewsJson.data.title.reviews.pageInfo;
  const nextPageKey = pageInfo.hasNextPage ? pageInfo.endCursor : undefined;
  return { results, nextPageKey };
}
