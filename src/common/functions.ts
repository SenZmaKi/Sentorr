import { parseDocument } from "htmlparser2"; // htmlparser2 is faster at loading string to document than cheerio
import { load as cheerioLoad, type CheerioAPI } from "cheerio";

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
  const doc = parseDocument(htmlPage);
  return cheerioLoad(doc);
}

export function zfill(num: number): string {
  return num.toString().padStart(2, "0");
}
type Success<T> = [data: T, error: undefined];

type Failure<E> = [data: undefined, error: E];

export type Result<T, E = Error> = Success<T> | Failure<E>;

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
