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
} from "./types";
import {
  type AdvancedTitleSearchResultJson,
  type BaseNode,
  type EpisodesResultsJson,
  type FanFavoritesResultJson,
  type MediaMetadataJson,
  type PopularTitlesJson,
  type MoreMetadataJson,
} from "./jsonTypes";
import { DEFAULT_RESULTS_LIMIT, mediaTypeMap } from "./constants";
import { filterMap, getFirst, parseHtml } from "@/common/functions";
import { DEBUG, CLIENT } from "@/common/constants";
import { type CheerioAPI } from "cheerio";
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
  const split = url.url.split(".");
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

export const getSessionCookies: () => Promise<string[]> = (function () {
  let sessionCookies: string[] | undefined = undefined;
  return async function () {
    if (!sessionCookies) {
      const response = await CLIENT.get(HOME_URL);
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
  const response = await CLIENT.get(url, headers, cookies);
  const resp_json = await response.json();
  if (DEBUG) {
    // console.log(
    //   `Url: ${url}\nStatus Code: ${response.status}\nJson:\n${JSON.stringify(resp_json, undefined, 4)}`,
    // );
    console.log("IMDB api call made");
  }
  return resp_json;
}

function buildBaseResult(node: BaseNode): BaseResult {
  const id = node.id;
  const title = node.titleText?.text;
  const rating = node.ratingsSummary?.aggregateRating;
  const ratingCount = node.ratingsSummary?.voteCount;
  const type =
    node.titleType?.displayableProperty?.value?.plainText ||
    node.titleType?.text;
  const url = node.primaryImage?.url;
  const imageUrl = url ? { url } : undefined;
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

// This seems to be the only request that needs the session cookies
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
  return fanFavoritesJson.data.fanPicksTitles.edges.map((edge) =>
    buildBaseResult(edge.node),
  );
}

export async function getPopularTitles(): Promise<BaseResult[]> {
  const variables = {
    limit: DEFAULT_RESULTS_LIMIT,
    ...DEFAULT_RECOMMENDATIONS_VARIABLES,
    queryFilter: { releaseDateRange: { end: DATE_STR } },
  };
  const url = generateAPIURL("PopularTitles", variables, POPULAR_TITLES_HASH);
  const popularTitleJson = (await apiGet(url)) as PopularTitlesJson;
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
      anyTitleTypeIds: mediaTypes.map((mediaType) => mediaTypeMap[mediaType]),
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
    advancedTitleSearchResultJson.data.advancedTitleSearch.edges.map((edge) =>
      buildBaseResult(edge.node.title),
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
  const episodesResultsJson = (await apiGet(url)) as EpisodesResultsJson;
  const results = episodesResultsJson.data.title.episodes.episodes.edges.map(
    (edge) => {
      const ep = edge.node;
      const id = ep.id;
      const title = ep.titleText.text;
      const number = parseInt(
        ep.series.displayableEpisodeNumber.episodeNumber.displayableProperty
          .value.plainText,
      );
      const imageUrl = { url: ep.primaryImage.url };
      const plot = ep.plot?.plotText.plaidHtml;
      const releaseDate = ep.releaseDate
        ? {
            day: ep.releaseDate.day,
            month: ep.releaseDate.month,
            year: ep.releaseDate.year,
          }
        : undefined;
      const rating = ep.ratingsSummary.aggregateRating;
      const ratingCount = ep.ratingsSummary.voteCount;
      return {
        id,
        title,
        number,
        seasonNumber,
        imageUrl,
        plot,
        releaseDate,
        rating,
        ratingCount,
      };
    },
  );
  const pageInfo = episodesResultsJson.data.title.episodes.episodes.pageInfo;
  const nextPageKey = pageInfo.hasNextPage ? pageInfo.endCursor : undefined;
  return { results, nextPageKey };
}

export async function getMedia(mediaID: string): Promise<Media> {
  const url = `${HOME_URL}title/${mediaID}`;
  const response = await CLIENT.get(url);
  const page = await response.text();
  const $ = parseHtml(page);
  const ldJsonStr = $('script[type="application/ld+json"]').text();
  const metadataJson = JSON.parse(ldJsonStr) as MediaMetadataJson;
  const moreldJsonStr = $("script#\\__NEXT_DATA__").text();
  const moreMetadataJson = JSON.parse(moreldJsonStr) as MoreMetadataJson;
  return combineMetadata(metadataJson, moreMetadataJson);
}

function combineMetadata(
  metadataJson: MediaMetadataJson,
  moreMetadata: MoreMetadataJson,
): Media {
  const title = metadataJson.name;
  const url = metadataJson.image;
  const imageUrl = url ? { url } : undefined;
  const bannerImageUrl = metadataJson.trailer?.thumbnailUrl;
  const trailerUrl = metadataJson.trailer?.embedUrl;
  const genres = metadataJson.genre as Genre[] | undefined;
  const rating = metadataJson.aggregateRating?.ratingValue;
  const ratingCount = metadataJson.aggregateRating?.ratingCount;
  const directors = metadataJson.director?.map((d) => d.name);
  const creators = filterMap(metadataJson.creator ?? [], (cr) => cr.name);
  const contentRating = metadataJson.contentRating;
  const aboveTheFoldData = moreMetadata.props.pageProps.aboveTheFoldData;
  const id = aboveTheFoldData.id;
  const endYear = aboveTheFoldData.releaseYear?.endYear;
  const releaseYear = aboveTheFoldData.releaseYear?.year;
  const popularityScore = aboveTheFoldData.meterRanking?.currentRank;
  const plot = aboveTheFoldData.plot?.plotText?.plainText;
  const runtime =
    aboveTheFoldData.runtime?.displayableProperty?.value?.plainText;
  const productionStatus =
    aboveTheFoldData.productionStatus?.currentProductionStage?.text;
  const type = aboveTheFoldData.titleType?.text as MediaType | undefined;
  const mainColumnData = moreMetadata.props.pageProps.mainColumnData;
  const episodeCount = mainColumnData?.episodes?.totalEpisodes?.total;
  const seasonsCount = mainColumnData?.episodes?.seasons?.length;
  const recommendations = mainColumnData.moreLikeThisTitles.edges.map(
    (rec) => buildBaseResult(rec.node),
    plot,
  );
  const actors = mainColumnData.cast.edges.map((edge) => {
    const name = edge.node.name.nameText.text;
    const imageUrl = edge.node.name.primaryImage?.url;
    const c = getFirst(edge.node.characters ?? []); // Characters is probably an array cause an actor can play multiple characters e.g., an alter ego from a different universe
    const character = c ? c.name : undefined;
    return { name, imageUrl, character };
  });

  const isMovie = type == MediaType.TVMovie || type == MediaType.Movie;
  const isOngoing = !isMovie && !!releaseYear && !endYear;
  return {
    id,
    title,
    type,
    imageUrl,
    bannerImageUrl,
    trailerUrl,
    plot,
    genres,
    releaseYear,
    rating,
    ratingCount,
    popularityScore,
    contentRating,
    actors,
    directors,
    runtime,
    recommendations,
    productionStatus,
    creators,
    seasonsCount,
    episodeCount,
    endYear,
    isMovie,
    isOngoing,
  };
}

function extractReviews($: CheerioAPI): Review[] {
  return $("div.review-container > div.lister-item-content")
    .toArray()
    .map((el) => {
      const rD = $(el);
      const title = rD.find("a.title").text().trim();
      const ratingStr = rD
        .find(
          "div.ipl-ratings-bar > span.rating-other-user-rating > span:first",
        )
        .text();
      let rating: number | undefined = undefined;
      if (ratingStr) {
        rating = parseInt(ratingStr);
      }
      const authorAndDateDiv = rD.find("div.display-name-date");
      const author = authorAndDateDiv.find("span.display-name-link > a").text();
      const date = authorAndDateDiv.find("span.review-date").text();
      const contentDiv = rD.find("div.content");
      const content = contentDiv.find("div.text").text();
      const foundHelpFulStr = contentDiv
        .find("div.actions")
        .text()
        .trim()
        .replace(/,/g, "");
      const [likesStr, , , totalStr] = foundHelpFulStr.split(" ");
      const likes = parseInt(likesStr);
      const dislikes = parseInt(totalStr) - likes;
      const hasSpoilers = rD.find("span.spoiler-warning").length > 0;
      return {
        title,
        author,
        rating,
        content,
        date,
        likes,
        dislikes,
        hasSpoilers,
      };
    });
}
export async function getReviews(
  mediaID: string,
  hideSpoilers: boolean,
  pageKey?: string,
): Promise<Pagination<Review[]>> {
  const url = `${HOME_URL}title/${mediaID}/reviews/_ajax?&sort=curated&dir=desc&ratingFilter=0&paginationKey=${pageKey || ""}${hideSpoilers ? "&spoiler=hide" : ""}`;
  const response = await CLIENT.get(url);
  const page = await response.text();
  const $ = parseHtml(page);
  const results = extractReviews($);
  const nextPageKey = $("div.load-more-data").attr("data-key");
  return { results, nextPageKey };
}
