import { CLIENT } from "@/common/types.js";
import { parseHtml, zfill } from "@/common/functions.js";
import { Torrent } from "./types.js";
import { CheerioAPI, Element } from "cheerio";
import * as vfp from "@ctrl/video-filename-parser";

const HOME_URL = "https://rargb.to";

export async function getSeriesTorrents(
  title: string,
  seasonNumber: number,
  episodeNumber: number | undefined,
) {
  const getCompleteSeason = episodeNumber === undefined;
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
    );
    if (newTorrent) {
      await updateTorrentList(
        torrents,
        newTorrent,
        pageResource,
        getCompleteSeason,
      );
    }
  }
  return torrents;
}

function parseTorrentElement(
  $: CheerioAPI,
  el: Element,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
): [Torrent | undefined, string] {
  const cheerioEl = $(el);
  const td = cheerioEl.find("td");
  const torrentTitleElement = td.eq(1).find("a");
  const mediaType = td.eq(2).find("a:first").text();
  const seeders = parseInt(td.eq(5).find("font").text());

  if (
    (isTvSeries && mediaType === "TV") ||
    (!isTvSeries && mediaType === "Movies")
  ) {
    const pageResource = torrentTitleElement.attr("href") as string;
    const info = torrentTitleElement.text();
    const parsed = vfp.filenameParse(info, isTvSeries);
    const title = parsed.title;
    const resolution = parsed.resolution;
    const isCompleteSeason = parsed.complete ?? false;

    if (
      resolution &&
      pageResource &&
      isCompleteSeason === getCompleteSeason &&
      parsed.languages.includes(vfp.Language.English)
    ) {
      return [
        {
          title,
          resolution,
          magnetLink: "",
          seeders,
          isCompleteSeason,
        },
        pageResource,
      ];
    }
  }

  return [undefined, ""];
}

async function updateTorrentList(
  torrents: Torrent[],
  newTorrent: Torrent,
  pageResource: string,
  getCompleteSeason: boolean,
): Promise<void> {
  const idx = torrents.findIndex(
    (torr) => torr.resolution === newTorrent.resolution,
  );
  const pageLink = `${HOME_URL}${pageResource}`;
  if (
    idx !== -1 &&
    !getCompleteSeason &&
    newTorrent.seeders >= torrents[idx].seeders
  ) {
    await getMagnetLinkAndUpdateList(torrents, idx, newTorrent, pageLink);
  } else if (newTorrent.seeders > 0) {
    await getMagnetLinkAndUpdateList(torrents, idx, newTorrent, pageLink);
  }
}

async function getMagnetLinkAndUpdateList(
  torrents: Torrent[],
  idx: number,
  newTorrent: Torrent,
  pageLink: string,
): Promise<void> {
  const $ = parseHtml(await (await CLIENT.get(pageLink)).text());
  const href = $("td.lista > a").eq(1).attr("href") as string;
  const magnetLink = href.includes("magnet:?") ? href : undefined;
  if (magnetLink) {
    if (idx !== -1) {
      torrents[idx] = { ...newTorrent, magnetLink };
    } else {
      torrents.push({ ...newTorrent, magnetLink });
    }
  }
}
