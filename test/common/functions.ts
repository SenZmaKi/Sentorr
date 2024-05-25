import path from "node:path/posix";
// @ts-ignore
import { expect } from "bun:test";
import { ROOT_DIR } from "./constants.js";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";

export function saveResults<T>(name: string, results: T) {
  const resultsJson = JSON.stringify(results, null, 2);
  const resultsSaveFolder = path.join(ROOT_DIR, "src", "test-results");
  if (!existsSync(resultsSaveFolder)) {
    mkdirSync(resultsSaveFolder, {});
  }
  const saveFilePath = path.join(resultsSaveFolder, `${name}.json`);
  writeFileSync(saveFilePath, resultsJson, { mode: 0o755 });
}

export function emptyArrayTest<T>(name: string, array: T[]) {
  saveResults(name, array);
  expect(array.length).toBeTruthy();
}

export async function emptyArrayTestHandler<T>(
  name: string,
  callback: () => Promise<Array<T>>,
) {
  const array = await callback();
  emptyArrayTest(name, array);
}

// Apparently typed json objects have different constructors from usual objects or sth
// So ```object instanceof Object``` won't work
function isJsonObject(object: any): boolean {
  const t = typeof object;
  return ![
    "boolean",
    "number",
    "string",
    "symbol",
    "function",
    "undefined",
  ].includes(t);
}
export function throwErrorIfContainsFalsy(object: any, except: string[] = []) {
  if (!isJsonObject(object)) {
    throw new Error(`ValueError - Expected ${object} to be a JSON object`);
  }
  const entries = Object.entries(object);
  for (const [key, value] of entries) {
    if (!except.includes(key)) {
      if (
        value !== false &&
        value !== 0 &&
        (!value || (Array.isArray(value) && value.length === 0))
      ) {
        throw new Error(
          `FalsyError - Expected { ${key}: ${value} }  to be truthy`,
        );
      } else if (isJsonObject(value)) {
        throwErrorIfContainsFalsy(value, except);
      }
    }
  }
}

export function findFalsyKeys(object: any, except: string[] = []): string[] {
  if (!isJsonObject(object)) {
    throw new Error(`ValueError - Expected ${object} to be a JSON object`);
  }
  const entries = Object.entries(object);
  for (const [key, value] of entries) {
    if (
      value !== false &&
      value !== 0 &&
      (!value || (Array.isArray(value) && value.length === 0))
    ) {
      if (!except.includes(key)) {
        except.push(key);
      }
    } else if (isJsonObject(value)) {
      findFalsyKeys(value, except);
    }
  }
  return except;
}
