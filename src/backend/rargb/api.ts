import { CLIENT } from "@/common/constants";
import { parseHtml, } from "@/common/functions";
import { type Torrent } from "./types";
import type { CheerioAPI, Element } from "cheerio";
import * as vfp from "@ctrl/video-filename-parser";

const HOME_URL = "https://rargb.to";

export async function getSeriesTorrents(
  title: string,
  seasonNumber: number,
  episodeNumber: number | undefined,
) {
  const getCompleteSeason = episodeNumber === undefined;
  const zfill = (num: number) => num.toString().padStart(2, "0");
  const epsStr = getCompleteSeason ? "" : `E${zfill(episodeNumber)}`;
  const formattedTitle = `${title} S${zfill(seasonNumber)}${epsStr}`;
  return getTorrents(formattedTitle, getCompleteSeason, true);
}

export async function getMovieTorrents(title: string) {
  return getTorrents(title, false, false);
}

async function getTorrents(
  mediaTItle: string,
  getCompleteSeason: boolean,
  isTvSeries: boolean,
  torrents: Torrent[] = [],
): Promise<Torrent[]> {
  const url = `${HOME_URL}/search/?search=${mediaTItle}&order=seeders&by=DESC`;
  const $ = parseHtml(await (await CLIENT.get(url)).text());
  const torrentElements = $("tr.lista2");
  for (const el of torrentElements) {
    const [newTorrent, pageResource] = parseTorrentElement(
      $,
      el,
      isTvSeries,
      getCompleteSeason,
    ) ?? [undefined, undefined];
    if (newTorrent) await updateTorrentList(torrents, newTorrent, pageResource);

  }
  return torrents;
}

function parseTorrentElement(
  $: CheerioAPI,
  el: Element,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
): [Torrent, string] | undefined {
  const cheerioEl = $(el);
  const td = cheerioEl.find("td");
  const torrentPageLinkElement = td.eq(1).find("a");
  const mediaType = td.eq(2).find("a:first").text();
  const seeders = parseInt(td.eq(5).find("font").text());
  if (
    (isTvSeries && mediaType !== "TV") ||
    (!isTvSeries && mediaType !== "Movies")
  ) {
    return undefined;
  }
  const pageResource = torrentPageLinkElement.attr("href");
  const filename = torrentPageLinkElement.text();
  const parsed = vfp.filenameParse(filename, isTvSeries);
  const title = parsed.title;
  const resolution = parsed.resolution;
  const isCompleteSeason = parsed.complete ?? false;
  if (
    resolution &&
    pageResource &&
    isCompleteSeason === getCompleteSeason &&
    parsed.languages.includes(vfp.Language.English)
  ) return [
    {
      title,
      resolution,
      magnetLink: "",
      seeders,
      isCompleteSeason,
    },
    pageResource,
  ];
  return undefined;
}

async function updateTorrentList(
  torrents: Torrent[],
  newTorrent: Torrent,
  pageResource: string,
): Promise<void> {
  const idx = torrents.findIndex(
    (torr) => torr.resolution === newTorrent.resolution,
  );
  const pageLink = `${HOME_URL}${pageResource}`;
  if (
    !newTorrent.seeders || (idx !== -1 && newTorrent.seeders <= torrents[idx].seeders)
  ) {
    return;
  }
  const $ = parseHtml(await (await CLIENT.get(pageLink)).text());
  const magnetLink = $("td.lista > a").eq(1).attr("href");
  if (!magnetLink || !magnetLink.includes("magnet:?")) {
    return;
  }
  if (idx === -1) {
    torrents.push({ ...newTorrent, magnetLink });
  } else {
    torrents[idx] = { ...newTorrent, magnetLink };
  }
}