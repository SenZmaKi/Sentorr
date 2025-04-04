import { parseDocument } from "htmlparser2";
import { load as cheerioLoad, type CheerioAPI } from "cheerio";
import type { Result } from "./types";
import { IS_BROWSER } from "./constants";

/**
 * Convenience function to quickly stringify an object for logging
 * @param ignoreBrowser If `true` will not stringify the object if running in the browser cause devtools log objects better. Default `true`
 *
 */
export function jsonStringify(object: any, space = 2, ignoreBrowser = true) {
  if (ignoreBrowser && IS_BROWSER) return object;
  return JSON.stringify(object, null, space);
}

export function printRunTimeLater(task: string = ""): () => void {
  const currentTime = new Date().getTime();
  return () => console.log(`${task}: ${new Date().getTime() - currentTime} ms`);
}

export function randomNumber({
  min = 0,
  max = 1,
  allowFloats = false,
}: {
  min?: number;
  max?: number;
  allowFloats?: boolean;
}): number {
  const floatResult = Math.random() * (max - min) + min;
  return allowFloats ? floatResult : Math.floor(floatResult);
}

/**
 * Maps an array by the `callbackfn` then filters out the `undefined` values yielded from the map
 */
export function filterMap<E, T>(
  array: Array<E>,

  callbackfn: (elem: E) => T | undefined,
): Array<T> {
  return array.map(callbackfn).filter((elem) => elem !== undefined);
}

export function parseHtml(htmlPage: string): CheerioAPI {
  //// htmlparser2 is faster at parsing html than cheerio
  const doc = parseDocument(htmlPage);
  return cheerioLoad(doc);
}

export function zfill(num: number, count = 2): string {
  return num.toString().padStart(count, "0");
}

export async function tryCatchAsync<T, E = Error>(
  promise: Promise<T>,
): Promise<Result<T, E>> {
  try {
    const data = await promise;
    return [data, undefined];
  } catch (error) {
    return [undefined, error as E];
  }
}
export function tryCatch<T, E = Error>(fn: () => T): Result<T, E> {
  try {
    const data = fn();
    return [data, undefined];
  } catch (error) {
    return [undefined, error as E];
  }
}
