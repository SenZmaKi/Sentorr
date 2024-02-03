import { parseDocument as htmlparser2 } from "htmlparser2";
import { load as cheerioLoad, CheerioAPI } from "cheerio";
export function printRunTimeLater(task: string = ""): () => void {
    const currentTime = new Date().getTime();

    return () => { return console.log(`${task}: ${new Date().getTime() - currentTime} ms`) };
}

export function zfill(num: number | string): string {
    num = num.toString();
    return num.padStart(num.length + 1, "0");
}
export function parseHtml(htmlPage: string): CheerioAPI {
    const doc = htmlparser2(htmlPage);
    const $ = cheerioLoad(doc);
    return $;
}

export function capitalise(str: string): string {
    if (!str) { return str };
    return str.charAt(0).toUpperCase() + str.slice(1);
}
export function getLast<T>(array: Array<T>): T | undefined {
    if (!Array.isArray(array)) { return undefined };
    if (array.length === 0) { return undefined };
    return array[array.length - 1];
}

const strip = (s: string) => s.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
export function fuzzyCompare(string1: string, string2: string): boolean {
    return strip(string1) === strip(string2);
}

export function getFirst<T>(array: Array<T>): T | undefined {
    if (!Array.isArray(array)) { return undefined };
    if (array.length === 0) { return undefined };

    return array[0];
}
