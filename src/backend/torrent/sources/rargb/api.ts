import { netClient } from "@/common/constants";
import { parseHtml } from "@/common/functions";
import { type GetTorrentFilesParams, type TorrentFile } from "../common/types";
import type { CheerioAPI, Element } from "cheerio";
import { parseSize, validateTorrent } from "../common/functions";
import type { Language } from "@ctrl/video-filename-parser";

const HOME_URL = "https://rargb.to";
/**
 * Client.get() wrapper to handle rate limiting
 **/
const get = (() => {
  let mutex = Promise.resolve();
  return async (url: string) => {
    await mutex;
    const response = await netClient.get(url);
    if (response.status !== 429) return response;
    const retryAfter = response.headers.get("Retry-After");
    const seconds = retryAfter ? parseInt(retryAfter) : 10; // They usually return 10 seconds so we use it as default
    console.log("Rate limited, retrying after", seconds, "seconds");
    mutex = new Promise((resolve) => setTimeout(resolve, seconds * 1000));
    return get(url);
  };
})();

export async function getTorrentFiles({
  seasonFormattedTitle,
  title,
  getCompleteSeason,
  isTvSeries,
  languages,
}: GetTorrentFilesParams): Promise<TorrentFile[]> {
  const url = `${HOME_URL}/search/?search=${seasonFormattedTitle}&order=seeders&by=DESC`;
  const response = await get(url);
  const htmlPage = await response.text();
  const $ = parseHtml(htmlPage);
  const torrentElements = $("tr.lista2");
  const torrentFiles: TorrentFile[] = [];
  for (const el of torrentElements) {
    const result = parseTorrentElement(
      $,
      el,
      title,
      isTvSeries,
      getCompleteSeason,
      languages,
    );
    if (!result) continue;
    const { torrentFile: newTorrentFile, pageResource } = result;
    await updateTorrentFilesArray(torrentFiles, newTorrentFile, pageResource);
  }
  return torrentFiles;
}

function parseTorrentElement(
  $: CheerioAPI,
  elem: Element,
  title: string,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
  languages: Language[],
): { torrentFile: TorrentFile; pageResource: string } | undefined {
  const cheerioEl = $(elem);
  const td = cheerioEl.find("td");
  const mediaType = td.eq(2).find("a:first").text();
  if (
    (isTvSeries && mediaType !== "TV") ||
    (!isTvSeries && mediaType !== "Movies")
  ) {
    return undefined;
  }
  const torrentPageLinkElement = td.eq(1).find("a");
  const filename = torrentPageLinkElement.text();
  const result = validateTorrent(
    title,
    filename,
    isTvSeries,
    getCompleteSeason,
    languages,
  );

  if (!result) return undefined;
  const { resolution } = result;
  const pageResource = torrentPageLinkElement.attr("href") as string;
  const seeders = parseInt(td.eq(5).find("font").text());
  if (!seeders) return undefined;
  const dateUploadedStr = td.eq(3).text();
  const dateUploadedISO = new Date(dateUploadedStr).toISOString();
  const size_str = td.eq(4).text();
  const sizeBytes = parseSize(size_str);
  if (!sizeBytes) return undefined;
  return {
    torrentFile: {
      filename,
      resolution,
      torrentID: "",
      seeders,
      isCompleteSeason: getCompleteSeason,
      sizeBytes,
      dateUploadedISO,
    },
    pageResource,
  };
}

async function updateTorrentFilesArray(
  torrentFiles: TorrentFile[],
  newTorrentFile: TorrentFile,
  pageResource: string,
): Promise<void> {
  const idx = torrentFiles.findIndex(
    (torr) => torr.resolution === newTorrentFile.resolution,
  );
  const pageLink = `${HOME_URL}${pageResource}`;
  if (
    !newTorrentFile.seeders ||
    (idx !== -1 && newTorrentFile.seeders <= torrentFiles[idx].seeders)
  ) {
    return;
  }
  const response = await get(pageLink);
  const $ = parseHtml(await response.text());
  const magnetURI = $("td.lista > a").eq(1).attr("href");
  if (!magnetURI || !magnetURI.includes("magnet:?")) {
    return;
  }
  if (idx === -1) {
    torrentFiles.push({ ...newTorrentFile, torrentID: magnetURI });
  } else {
    torrentFiles[idx] = { ...newTorrentFile, torrentID: magnetURI };
  }
}
