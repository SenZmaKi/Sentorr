import { CLIENT } from "@/common/constants";
import { filterMap, parseHtml } from "@/common/functions";
import type { Cheerio, Element } from "cheerio";
import { validateTorrent } from "../common/functions";
import type { TorrentFile } from "../common/types";
import { writeFileSync } from "fs";
import type { Language } from "@ctrl/video-filename-parser";

const HOME_URL = "https://thepiratebay.org";

export async function getTorrentFiles(
  seasonFormattedTitle: string,
  title: string,
  getCompleteSeason: boolean,
  isTvSeries: boolean,
  languages: Language[],
) {
  const url = `${HOME_URL}/search.php?q=${seasonFormattedTitle}`;
  const response = await CLIENT.get(url);
  console.log(`${HOME_URL}/search.php?q=${seasonFormattedTitle}`);
  const htmlPage = await response.text();
  writeFileSync("pirate.html", htmlPage);
  const $ = parseHtml(htmlPage);
  return filterMap($("ol.view-single > li.list-entry").toArray(), (elem) =>
    parseTorrentElement(
      $(elem),
      title,
      getCompleteSeason,
      isTvSeries,
      languages,
    ),
  );
}

function parseTorrentElement(
  elem: Cheerio<Element>,
  title: string,
  getCompleteSeason: boolean,
  isTvSeries: boolean,
  languages: Language[],
): TorrentFile | undefined {
  const category = elem.find("span.item-type").find("a:first").text();
  console.log("category", category);
  if (category !== "Video") return undefined;
  const filename = elem.find("span.item-title").find("a").text();
  const result = validateTorrent(
    title,
    filename,
    isTvSeries,
    getCompleteSeason,
    languages,
  );
  if (!result) return undefined;
  const { resolution } = result;
  const dateUploaded = elem.find("span.item-uploaded").text();
  const magnetURI = elem.find("span.item-icons > a").attr("href") as string;
  const size = elem.find("span.item-size").text();
  const seedersStr = elem.find("span.item-seed").text();
  const seeders = parseInt(seedersStr);
  return {
    filename,
    dateUploaded,
    torrentID: magnetURI,
    size,
    seeders,
    resolution,
    isCompleteSeason: getCompleteSeason,
  };
}
