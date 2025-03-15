import {
  filenameParse,
  parseSeason as vfpParseSeason,
  Language,
  Resolution as VfpResolution,
  type ParsedShow,
  type ParsedMovie,
} from "@ctrl/video-filename-parser";
import levenshtein from "js-levenshtein";
import { Resolution, RESOLUTIONS, type TorrentFile } from "./types";
import { zfill } from "@/common/functions";

export function seasonFormatTitle(
  title: string,
  seasonNumber: number,
  episodeNumber?: number,
) {
  const epsStr = episodeNumber ? `E${zfill(episodeNumber)}` : "";
  const abbrvSeasonTitle = `${title} S${zfill(seasonNumber)}${epsStr}`;
  const fullSeasonTitle = `${title} Season ${seasonNumber}`;
  return { abbrvSeasonTitle, fullSeasonTitle };
}
export function parseSize(size: string): number | undefined {
  const units = ["B", "KB", "MB", "GB", "TB", "PB"]; // Ordered list of units
  const regex = /^([\d.]+)\s*(B|KB|MB|GB|TB|PB)$/i; // Regex to capture the number and unit

  const match = size.trim().match(regex);
  if (!match) {
    console.warn(`Failed to parse size from ${size}`);
    return undefined;
  }
  const value = parseFloat(match[1]); // Extract numeric part
  const unit = match[2].toUpperCase(); // Normalize unit to uppercase
  const unitIndex = units.indexOf(unit);
  return value * Math.pow(1024, unitIndex); // Convert to bytes
}

export function parseResolution(vfpResolution: VfpResolution) {
  switch (vfpResolution) {
    case VfpResolution.R2160P:
      return Resolution.R2160P;
    case VfpResolution.R1080P:
      return Resolution.R1080P;
    case VfpResolution.R720P:
      return Resolution.R720P;
    case VfpResolution.R576P:
      return Resolution.R576P;
    case VfpResolution.R540P:
      return Resolution.R540P;
    case VfpResolution.R480P:
      return Resolution.R480P;
  }
}
export function validateTorrent(
  title: string,
  filename: string,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
  languages: Language[],
  ignoreTitle?: boolean,
) {
  const { isSame, parsedFilename } = (
    ignoreTitle
      ? { isSame: true, parsedFilename: filenameParse(filename) }
      : isSameTitle(title, filename, isTvSeries)
  ) as {
    isSame: boolean;
    parsedFilename: typeof isTvSeries extends true ? ParsedShow : ParsedMovie;
  };
  if (
    !isSame ||
    !parsedFilename.resolution ||
    !parsedFilename.languages.some((lang) => languages.includes(lang)) ||
    (isTvSeries &&
      !getCompleteSeason ===
        (!!parsedFilename.complete ||
          !!(parsedFilename as ParsedShow).fullSeason))
  )
    return undefined;
  const resolution = parseResolution(parsedFilename.resolution);
  return {
    resolution,
  };
}

export function isSameTitle(
  title: string,
  filename: string,
  isTvSeries: boolean,
) {
  let parsedFilename = filenameParse(filename, isTvSeries);
  let similarity = calculateSimilarityPercentage(
    title,
    parsedFilename.title,
    isTvSeries,
  );
  if (isTvSeries && similarity < 80) {
    console.log(
      `Reparsing: ${similarity}% "${title}" vs "${parsedFilename.title}"\n"${filename}"`,
    );
    parsedFilename = filenameParse(filename);
    similarity = calculateSimilarityPercentage(
      title,
      parsedFilename.title,
      isTvSeries,
    );
  }
  const isSame = similarity >= 80;
  if (!isSame)
    console.log(
      `Not same title: ${similarity}% "${title}" vs "${parsedFilename.title}"\n"${filename}"`,
    );
  return { isSame, parsedFilename };
}

export function calculateSimilarityPercentage(
  a: string,
  b: string,
  isTvSeries: boolean,
): number {
  const strip = (str: string) => {
    str = a.toLowerCase().replace(/[^a-zA-Z0-9]/g, "");
    if (isTvSeries) str.replace(/season|s|episode|e|complete\d+/g, "");
    return str;
  };
  a = strip(a);
  b = strip(b);
  const leven = levenshtein(a, b) as number;
  const maxLength = Math.max(a.length, b.length);
  const similarity = maxLength - leven;
  const percentage = (similarity / maxLength) * 100;
  return percentage;
}

export function parseSeason(
  title: string,
  type: "torrentFile" | "torrentStream",
  parseEpisode: boolean,
) {
  const parsed = vfpParseSeason(title);
  if (!parsed) {
    console.warn(`Failed to parse ${type} season info: ${title}`);
    return undefined;
  }
  if (!parsed.seasons.length) {
    console.warn(
      `Failed to parse ${type} season number: ${title} parsed: ${JSON.stringify(parsed)}`,
    );
    return undefined;
  }
  if (parseEpisode && !parsed.episodeNumbers.length) {
    console.warn(
      `Failed to parse ${type} episode number: ${title} parsed: ${JSON.stringify(parsed)}`,
    );
    return undefined;
  }
  return {
    seasonNumbers: parsed.seasons,
    episodeNumbers: parsed.episodeNumbers,
  };
}

export function computeTorrentScores({
  torrents,
  preferredResolution,
  maxSeedersThreshold = Math.min(
    100,
    Math.max(...torrents.map((torrent) => torrent.seeders)),
  ),
  maxSizeThreshold = Math.max(...torrents.map((torrent) => torrent.sizeBytes)),
  seedersWeight = 0.375,
  resolutionWeight = 0.3,
  sizeWeight = 0.325,
  resolutionPardonFactor = 0.6,
}: {
  torrents: TorrentFile[];
  preferredResolution: Resolution;
  seedersWeight?: number;
  resolutionWeight?: number;
  sizeWeight?: number;
  maxSeedersThreshold?: number;
  maxSizeThreshold?: number;
  resolutionPardonFactor?: number;
}) {
  const minResolution = Math.min(...RESOLUTIONS);
  const maxResolutionDifference = Math.max(...RESOLUTIONS) - minResolution;
  return torrents.map((torrent) => {
    const resolutionDifference = Math.abs(
      torrent.resolution - preferredResolution,
    );
    const resolutionScore = 1 - resolutionDifference / maxResolutionDifference;

    const seedersScore = Math.min(torrent.seeders / maxSeedersThreshold, 1);
    let sizeBytes = torrent.sizeBytes;
    let seasonsCount = 0;

    if (torrent.filename && torrent.isCompleteSeason) {
      const parsedSeason = parseSeason(torrent.filename, "torrentFile", false);
      if (parsedSeason) {
        seasonsCount = parsedSeason.seasonNumbers.length;
        sizeBytes = sizeBytes / seasonsCount;
      }
    }
    let sizePenalty = Math.min(sizeBytes / maxSizeThreshold, 1);
    const resolutionPardon =
      (torrent.resolution - minResolution) / maxResolutionDifference;
    const pardonedSizePenalty =
      sizePenalty - resolutionPardon * resolutionPardonFactor;

    const score =
      -pardonedSizePenalty * sizeWeight +
      resolutionScore * resolutionWeight +
      seedersScore * seedersWeight;

    // console.log("filename", torrent.filename, "score", score, "seedersScore", seedersScore, "resolutionScore", resolutionScore, "sizePenalty", sizePenalty, "resolutionPardon", resolutionPardon, "pardonedSizePenalty", pardonedSizePenalty);
    return {
      torrent,
      score,
    };
  });
}
