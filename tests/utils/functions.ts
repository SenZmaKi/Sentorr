import { JsonObject } from "../../src/utils/types.js";
import {expect} from "bun:test";

export function emptyArrayTest(array: any[]) {
    expect(array.length).toBeTruthy();
}

export async function emptyArrayTestHandler(callback: () => Promise<Array<any>>) {
    const array = await callback();
    emptyArrayTest(array)
}

// Apparently typed json objects have different constructors from usual objects or sth
// So ```object instanceof Object``` won't work
function isJsonObject(object: JsonObject): boolean {
    const t = typeof object;
    return !['boolean', 'number', 'string', 'symbol', 'function', 'undefined'].includes(t);
}
export function throwErrorIfContainsFalsy(object: JsonObject, except: string[] = []) {
    if (!isJsonObject(object)) {
        throw new Error(`ValueError - Expected ${object} to be a JSON object`);
    }
    const entries = Object.entries(object);
    for (const [key, value] of entries) {
        if (!except.includes(key)) {
            if (value !== false && value !== 0 && (!value || Array.isArray(value) && value.length === 0)) {
                throw new Error(`FalsyError - Expected { ${key}: ${value} }  to be truthy`);
            } else if (isJsonObject(value)) {
                throwErrorIfContainsFalsy(value, except);
            }
        }
    }
}

export function findFalsyKeys(object: JsonObject, except: string[] = []): string[] {
    if (!isJsonObject(object)) {
        throw new Error(`ValueError - Expected ${object} to be a JSON object`);
    }
    const entries = Object.entries(object);
    for (const [key, value] of entries) {
        if (value !== false && value !== 0 && (!value || Array.isArray(value) && value.length === 0)) {
            if (!except.includes(key)) {
                except.push(key);
            }
        } else if (isJsonObject(value)) {
            findFalsyKeys(value, except);
        }
    }
    return except;
}
