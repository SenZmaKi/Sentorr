import { parseDocument as parseDocument } from "htmlparser2"; // htmlparser2 is faster at loading string to document than cheerio
import { load as cheerioLoad, CheerioAPI } from "cheerio";
export function printRunTimeLater(task: string = ""): () => void {
  const currentTime = new Date().getTime();
  return () => {
    return console.log(`${task}: ${new Date().getTime() - currentTime} ms`);
  };
}

/**
 * Maps an array by the callback then filters out the undefined values yielded from the map
 * @param array
 * @param callback  A function that returns a value or undefined
 * @returns
 */
export function filterMap<A, T>(
  array: Array<A>,
  callback: (elem: A) => T | undefined,
): Array<T> {
  return array.map(callback).filter((elem) => elem !== undefined) as Array<T>;
}

export function zfill(num: number | string): string {
  num = num.toString();
  return num.padStart(num.length + 1, "0");
}

export function parseHtml(htmlPage: string): CheerioAPI {
  const doc = parseDocument(htmlPage);
  return cheerioLoad(doc);
}

export function capitalise(str: string): string {
  if (!str) {
    return str;
  }
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function getLast<T>(array: Array<T>): T | undefined {
  if (array.length === 0) {
    return undefined;
  }
  return array[array.length - 1];
}

function strip(s: string): string {
  return s.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

export function fuzzyCompare(string1: string, string2: string): boolean {
  return strip(string1) === strip(string2);
}

export function getFirst<T>(array: Array<T>): T | undefined {
  if (array.length === 0) {
    return undefined;
  }
  return array[0];
}
