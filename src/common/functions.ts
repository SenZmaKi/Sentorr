import { parseDocument as parseDocument } from "htmlparser2"; // htmlparser2 is faster at loading string to document than cheerio
import { load as cheerioLoad, type CheerioAPI } from "cheerio";
import type { IpcResult } from "@/common/types";

export function printRunTimeLater(task: string = ""): () => void {
  const currentTime = new Date().getTime();
  return () => console.log(`${task}: ${new Date().getTime() - currentTime} ms`);
}

export function randomNumber(params: {
  min?: number;
  max?: number;
  allowFloats?: boolean;
}): number {
  const { min = 0, max = 1, allowFloats = false } = params;
  const floatResult = Math.random() * (max - min) + min;
  return allowFloats ? floatResult : Math.floor(floatResult);
}

export function isDigit(str: string): boolean {
  return /^\d+$/.test(str);
}

/**
 * Maps an array by the `callbackfn` then filters out the `undefined` values yielded from the map

 */

export function filterMap<E, T>(
  array: Array<E>,

  callbackfn: (elem: E) => T | undefined,
): Array<T> {
  return array.map(callbackfn).filter((elem) => elem !== undefined) as Array<T>;
}

export function parseHtml(htmlPage: string): CheerioAPI {
  return cheerioLoad(parseDocument(htmlPage));
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

function stripNonAlphaNumeric(s: string): string {
  return s.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

export function fuzzyCompare(string1: string, string2: string): boolean {
  return stripNonAlphaNumeric(string1) === stripNonAlphaNumeric(string2);
}

export function getFirst<T>(array: Array<T>): T | undefined {
  if (array.length === 0) {
    return undefined;
  }

  return array[0];
}

export function remove<T>(array: Array<T>, element: T): T | undefined {
  const idx = array.indexOf(element);

  if (idx === -1) {
    return undefined;
  }

  return array.splice(idx, 1)[0];
}

export async function invokeIpc<T>(channel: string, ...args: any): Promise<T> {
  const { error, result }: IpcResult<T> = await window.electron.ipcRenderer.invoke(channel, ...args);
  if (error !== undefined) throw new Error(error);
  return result;
}
