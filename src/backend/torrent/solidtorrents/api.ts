import { Client } from "@/common/constants";
import { filterMap, parseHtml } from "@/common/functions";
import type { Cheerio, Element } from "cheerio";
import { parseSize, validateTorrent } from "../common/functions";
import type { GetTorrentFilesParams, TorrentFile } from "../common/types";
import type { Language } from "@ctrl/video-filename-parser";

const HOME_URL = "https://solidtorrents.to";

export async function getTorrentFiles({
  seasonFormattedTitle,
  title,
  getCompleteSeason,
  isTvSeries,
  languages,
}: GetTorrentFilesParams) {
  const url = `${HOME_URL}/search?q=${seasonFormattedTitle}&sort=seeders`;
  const response = await Client.get(url);
  const htmlPage = await response.text();
  const $ = parseHtml(htmlPage);
  return filterMap($("li.search-result").toArray(), (elem) =>
    parseTorrentElement(
      $(elem),
      title,
      isTvSeries,
      getCompleteSeason,
      languages
    )
  );
}

function parseTorrentElement(
  elem: Cheerio<Element>,
  title: string,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
  languages: Language[]
): TorrentFile | undefined {
  const infoDiv = elem.find("div.info > div");
  const filename = infoDiv.find("h5 > a").text();
  const result = validateTorrent(
    title,
    filename,
    isTvSeries,
    getCompleteSeason,
    languages
  );
  if (!result) return undefined;
  const { resolution } = result;
  const bottomInfoDiv = infoDiv.find("div");
  const category = bottomInfoDiv.find("a").text();
  if (category === "XXX") return undefined;
  const statsDivs = bottomInfoDiv.find("div > div");
  const dateUploadedStr = statsDivs.eq(5).text();
  const dateUploadedISO = new Date(dateUploadedStr).toISOString();
  const size_str = statsDivs.eq(2).text();
  const sizeBytes = parseSize(size_str);
  if (!sizeBytes) return undefined;
  const fontDivs = statsDivs.find("font");
  const seeders = parseInt(fontDivs.eq(0).text());
  if (!seeders) return undefined;
  const magnetURI = elem.find("div.links > a.dl-magnet").attr("href") as string;
  return {
    filename,
    sizeBytes,
    seeders,
    resolution,
    torrentID: magnetURI,
    isCompleteSeason: getCompleteSeason,
    dateUploadedISO,
  };
}
