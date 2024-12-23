import {
  filenameParse,
  parseSeason as vfpParseSeason,
  Language,
} from "@ctrl/video-filename-parser";
import levenshtein from "js-levenshtein";

export function seasonFormatTitle(
  title: string,
  seasonNumber: number,
  episodeNumber?: number,
) {
  const zfill = (num: number) => num.toString().padStart(2, "0");
  const epsStr = episodeNumber ? `E${zfill(episodeNumber)}` : "";
  const abbrvSeasonTitle = `${title} S${zfill(seasonNumber)}${epsStr}`;
  const fullSeasonTitle = `${title} Season ${seasonNumber}`;
  return { abbrvSeasonTitle, fullSeasonTitle };
}

export function validateTorrent(
  title: string,
  filename: string,
  isTvSeries: boolean,
  getCompleteSeason: boolean,
  languages: Language[],
  ignoreTitle?: boolean,
) {
  const { isSame, parsedFilename } = ignoreTitle
    ? { isSame: true, parsedFilename: filenameParse(filename) }
    : isSameTitle(title, filename, isTvSeries);
  if (
    !isSame ||
    !parsedFilename.resolution ||
    !parsedFilename.languages.some((lang) => languages.includes(lang)) ||
    !getCompleteSeason ===
      // @ts-ignore fullSeason isn't defined in d.ts but it's there in the returned object
      (!!parsedFilename.complete || !!parsedFilename.fullSeason)
  )
    return undefined;
  return {
    resolution: parsedFilename.resolution,
  };
}

function isSameTitle(title: string, filename: string, isTvSeries: boolean) {
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
      `Not same: ${similarity}% "${title}" vs "${parsedFilename.title}"\n"${filename}"`,
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
  season: string,
  type: "torrentFile" | "torrentStream",
) {
  const parsed = vfpParseSeason(season);
  if (!parsed) {
    console.warn(`Failed to parse ${type} season info: ${season}`);
    return undefined;
  }
  if (parsed.seasons.length !== 1) {
    console.warn(`Failed to parse ${type} season number: ${season}`);
    return undefined;
  }
  if (parsed.episodeNumbers.length !== 1) {
    console.warn(`Failed to parse ${type} episode number: ${season}`);
    return undefined;
  }
  return {
    seasonNumber: parsed.seasons[0],
    episodeNumber: parsed.episodeNumbers[0],
  };
}
