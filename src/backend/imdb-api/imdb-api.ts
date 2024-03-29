import { CLIENT } from "../../utils/client.js";
import { JsonObject } from "../../utils/types.js";
import {
  Actor,
  AdvancedTitleSearchResultJson,
  BaseNode,
  BaseResult,
  Episode,
  EpisodesResultsJson,
  FanFavoritesResultJson,
  Genre,
  Media,
  MediaMetadataJson,
  Pagination,
  PopularTitlesJson,
  Range,
  ReleaseDateRange,
  Review,
  SortBy,
  SortOrder,
} from "./types.js";
import { DATE, DEFAULT_RESULTS_LIMIT, DEBUG } from "../../utils/constants.js";
import { capitalise, getFirst, parseHtml } from "../../utils/functions.js";
import { CheerioAPI } from "cheerio";
import { MoreMetadataJson } from "./more-metadata.js";

const HOME_URL = "https://imdb.com/";
const API_ENTRY_POINT = "https://graphql.imdb.com/?operationName=";
const DEFAULT_LOCALE = { locale: "en-US" };
const DEFAULT_RECOMMENDATIONS_VARIABLES = {
  ...DEFAULT_LOCALE,
  includeUserRating: false,
};
const DEFAUT_EPISODES_RESULTS_LIMIT = 250;
const FAN_FAVORITES_HASH =
  "7c01e0d9d8581975bf64701df0c96b02aaec777fdfc75734d68d009bde984b99"
const POPULAR_TITLES_HASH =
  "f928c4406df23ac79204ff916c3f7429d3a44c9aac069d332a9d7eb6932c4f2f"
const EPISODES_HASH =
  "e5b755e1254e3bc3a36b34aff729b1d107a63263dec628a8f59935c9e778c70e";
const ADVANCED_TITLE_SEARCH_HASH =
  "e7a1c7b10a7a9765731e5c874cef0342dfbd0dd7a87fa796e828778e54a07a20";
// IMDB API accepts data in ISO format YYYY-MM-DD
const DATE_STR = DATE.toISOString().split("T")[0];

let SESSION_COOKIES: string[] = [];

async function setSessionCookies(): Promise<string[]> {
  const response = await CLIENT.get(HOME_URL);
  const cookies = response.headers.getSetCookie();
  SESSION_COOKIES = cookies;
  return cookies;
}
function stringifyAndEncodeJson(json: JsonObject): string {
  return encodeURIComponent(JSON.stringify(json));
}
function generateAPIURL(
  operationName: string,
  variables: JsonObject,
  sha256Hash: string,
): string {
  const extensions = { persistedQuery: { sha256Hash: sha256Hash, version: 1 } };
  const url = `${API_ENTRY_POINT}${operationName}&variables=${stringifyAndEncodeJson(
    variables,
  )}&extensions=${stringifyAndEncodeJson(extensions)}`;
  return url;
}

async function apiGet(
  url: string,
  headers: HeadersInit | undefined = undefined,
  cookies: string[] = [],
): Promise<JsonObject> {
  headers = { ...headers, ...{ "Content-Type": "application/json" } };
  const response = await CLIENT.get(url, headers, cookies);
  const resp_json = await response.json();
  if (DEBUG) {
    console.log(
      `Url: ${url}\nStatus Code: ${response.status}\nJson:\n${JSON.stringify(resp_json, undefined, 4)}`,
    );
  }
  return resp_json;
}

function buildBaseResult(node: BaseNode): BaseResult {
  const id = node.id;
  const title = node.titleText.text;
  const rating = node.ratingsSummary?.aggregateRating;
  const ratingCount = node.ratingsSummary?.voteCount;
  let type = node.titleType?.displayableProperty?.value?.plainText;
  if (!type) {
    // For movies the type plainText is an empty string but the type is stored in the id value as "movie"
    const titleID = node?.titleType?.id;
    if (titleID) {
      type = capitalise(titleID);
    }
  }
  const imageUrl = node.primaryImage?.url;
  const releaseYear = node.releaseYear?.year;
  const endYear = node.releaseYear?.endYear;
  return {
    id,
    title,
    type,
    imageUrl,
    releaseYear,
    endYear,
    rating,
    ratingCount,
  };
}
// On IMDB the popularity is more akin to trending cause the popular media frequently change and are usually recently released media
async function getTop10Trending(): Promise<BaseResult[]> {
  const page = await filteredSearch({
    pageKey: "",
    sortBy: "POPULARITY",
    sortOrder: "ASC",
  });
  return page.results.slice(0, 10);
}

async function getTop10OfAllTime(): Promise<BaseResult[]> {
  const page = await filteredSearch({
    pageKey: "",
    sortBy: "USER_RATING_COUNT",
    sortOrder: "DESC",
  });
  return page.results.slice(0, 10);
}

// This seems to be the only request that needs the session cookies
async function getFanFavorites(): Promise<BaseResult[]> {
  const variables = {
    first: DEFAULT_RESULTS_LIMIT,
    ...DEFAULT_RECOMMENDATIONS_VARIABLES,
    locale: "en-US",
  };
  if (!SESSION_COOKIES.length) {
    await setSessionCookies();
  }
  const url = generateAPIURL("FanFavorites", variables, FAN_FAVORITES_HASH);
  const fanFavoritesJson = (await apiGet(
    url,
    undefined,
    SESSION_COOKIES,
  )) as FanFavoritesResultJson;
  const results: BaseResult[] = [];
  fanFavoritesJson.data.fanPicksTitles.edges.forEach((edge) =>
    results.push(buildBaseResult(edge.node)),
  );
  return results;
}

async function getPopularTitles(): Promise<BaseResult[]> {
  const variables = {
    limit: DEFAULT_RESULTS_LIMIT,
    ...DEFAULT_RECOMMENDATIONS_VARIABLES,
    queryFilter: { releaseDateRange: { end: DATE_STR } },
  };
  const url = generateAPIURL("PopularTitles", variables, POPULAR_TITLES_HASH);
  const popularTitleJson = (await apiGet(url)) as PopularTitlesJson;
  const results: BaseResult[] = [];
  popularTitleJson.data.popularTitles.titles.forEach((node) =>
    results.push(buildBaseResult(node)),
  );
  return results;
}

async function filteredSearch(filters: {
  pageKey?: string;
  searchTerm?: string;
  genres?: Genre[];
  sortBy?: SortBy;
  sortOrder?: SortOrder;
  ratingRange?: Range;
  ratingsCountRange?: Range;
  releaseDateRange?: ReleaseDateRange;
  runtimeRangeMinutes?: Range;
}): Promise<Pagination<BaseResult[]>> {
  const {
    pageKey = "",
    searchTerm = "",
    genres = [],
    sortBy = "USER_RATING_COUNT",
    sortOrder = "DESC",
    ratingRange = {},
    ratingsCountRange = {},
    releaseDateRange = {},
    runtimeRangeMinutes = {},
  } = filters;
  const variables = {
    ...DEFAULT_LOCALE,
    after: pageKey,
    first: DEFAULT_RESULTS_LIMIT,
    titleTextConstraint: { searchTerm: searchTerm },
    genreConstraint: { allGenreIds: genres },
    releaseDateConstraint: { releaseDateRange: releaseDateRange },
    runtimeConstraint: { runtimeRangeMinutes: runtimeRangeMinutes },
    sortBy: sortBy,
    sortOrder: sortOrder,
    userRatingsConstraint: {
      aggregateRatingRange: ratingRange,
      ratingsCountRange: ratingsCountRange,
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
  const results: BaseResult[] = [];
  advancedTitleSearchResultJson.data.advancedTitleSearch.edges.forEach((edge) =>
    results.push(buildBaseResult(edge.node.title)),
  );
  const nextPageKey =
    advancedTitleSearchResultJson.data.advancedTitleSearch.pageInfo.endCursor;
  return { nextPageKey, results };
}

async function getEpisodes(
  mediaID: string,
  seasonNumber: number,
  pageKey: string,
): Promise<Pagination<Episode[]>> {
  const variables = {
    ...DEFAULT_LOCALE,
    returnUrl: `${HOME_URL}close_me`,
    originalTitleText: false,
    after: pageKey,
    const: mediaID,
    first: DEFAUT_EPISODES_RESULTS_LIMIT,
    filter: { includeSeasons: [seasonNumber.toLocaleString()] },
  };
  const url = generateAPIURL(
    "TitleEpisodesSubPagePagination",
    variables,
    EPISODES_HASH,
  );
  const episodesResultsJson = (await apiGet(url)) as EpisodesResultsJson;
  const results: Episode[] = [];
  episodesResultsJson.data.title.episodes.episodes.edges.forEach((edge) => {
    const ep = edge.node;
    const id = ep.id;
    const title = ep.titleText.text;
    const number = parseInt(
      ep.series.displayableEpisodeNumber.episodeNumber.displayableProperty.value
        .plainText,
    );
    const imageUrl = ep.primaryImage.url;
    const plot = ep.plot?.plotText.plaidHtml;
    const releaseDate = `${ep.releaseDate.day}-${ep.releaseDate.month}-${ep.releaseDate.year}`;
    const rating = ep.ratingsSummary.aggregateRating;
    const ratingCount = ep.ratingsSummary.voteCount;
    results.push({
      id,
      title,
      number,
      seasonNumber,
      imageUrl,
      plot,
      releaseDate,
      rating,
      ratingCount,
    });
  });
  const nextPageKey =
    episodesResultsJson.data.title.episodes.episodes.pageInfo.endCursor;
  return { nextPageKey, results: results };
}

async function getMedia(mediaID: string): Promise<Media> {
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
  const imageUrl = metadataJson.image;
  const trailerUrl = metadataJson.trailer?.embedUrl;
  const genres = metadataJson.genre;
  const rating = metadataJson.aggregateRating?.ratingValue;
  const ratingCount = metadataJson.aggregateRating?.ratingCount;
  const directors: string[] = [];
  metadataJson.director?.forEach((val) => directors.push(val.name));
  const creators: string[] = [];
  metadataJson.creator?.forEach((cr) => {
    if (cr.name) {
      creators.push(cr.name);
    }
  });
  const contentRating = metadataJson.contentRating;
  const aboveTheFoldData = moreMetadata.props.pageProps.aboveTheFoldData;
  const id = aboveTheFoldData.id;
  const endYear = aboveTheFoldData.releaseYear?.endYear;
  const releaseYear = aboveTheFoldData.releaseYear?.year;
  const popularityScore = aboveTheFoldData.meterRanking?.currentRank;
  const plot = aboveTheFoldData.plot?.plotText?.plainText;
  const runtime =
    aboveTheFoldData.runtime?.displayableProperty?.value?.plainText;
  const recommendations: BaseResult[] = [];
  const productionStatus =
    aboveTheFoldData.productionStatus?.currentProductionStage?.text;
  const mainColumnData = moreMetadata.props.pageProps.mainColumnData;
  const episodeCount = mainColumnData?.episodes?.totalEpisodes?.total;
  const seasonsCount = mainColumnData?.episodes?.seasons?.length;
  mainColumnData.moreLikeThisTitles.edges.forEach((rec) => {
    recommendations.push(buildBaseResult(rec.node));
  });
  const actors: Actor[] = [];
  mainColumnData.cast.edges.forEach((edge) => {
    const name = edge.node.name.nameText.text;
    const imageUrl = edge.node.name.primaryImage?.url;
    const c = getFirst(edge.node.characters); // Idk why characters is an array maybe whoever made the choice thought one actor could play 2 or more characters or sth
    const character = c ? c.name : undefined;
    actors.push({ name, imageUrl, character });
  });

  return {
    id,
    title,
    imageUrl,
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
  };
}

function extractReviews($: CheerioAPI): Review[] {
  const reviewDivs = $("div.review-container > div.lister-item-content");
  const reviews: Review[] = [];
  reviewDivs.each((_, el) => {
    const rD = $(el);
    const title = rD.find("a.title").text().trim();
    const ratingStr = rD
      .find("div.ipl-ratings-bar > span.rating-other-user-rating > span:first")
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
    const review = {
      title,
      author,
      rating,
      content,
      date,
      likes,
      dislikes,
      hasSpoilers,
    };
    reviews.push(review);
  });
  return reviews;
}
async function getReviews(
  mediaID: string,
  pageKey: string,
  hideSpoilers: boolean,
): Promise<Pagination<Review[]>> {
  let url = `${HOME_URL}title/${mediaID}/reviews/_ajax?&sort=curated&dir=desc&ratingFilter=0&paginationKey=${pageKey}`;
  if (hideSpoilers) {
    url += "&spoiler=hide";
  }
  const response = await CLIENT.get(url);
  const page = await response.text();
  const $ = parseHtml(page);
  const results = extractReviews($);
  const nextPaginationKeyDiv = $("div.load-more-data").attr("data-key");
  const nextPageKey = nextPaginationKeyDiv ?? "";
  return { nextPageKey, results: results };
}

export {
  filteredSearch,
  getEpisodes,
  getFanFavorites,
  getMedia,
  getPopularTitles,
  getReviews,
  getTop10OfAllTime,
  getTop10Trending,
  setSessionCookies,
};
