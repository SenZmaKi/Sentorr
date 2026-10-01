import path from "path";
import { expect } from "bun:test";
import { exists, mkdir, writeFile } from "fs/promises";

export async function saveResults<T>(name: string, results: T) {
  const resultsJson = JSON.stringify(results, null, 2);
  const split = name.split("/");
  const filename = split.pop();
  const resultsSaveFolder = path.join("src", "test", "results", ...split);
  if (!(await exists(resultsSaveFolder)))
    await mkdir(resultsSaveFolder, { recursive: true });
  const saveFilePath = path.join(resultsSaveFolder, `${filename}.json`);
  await writeFile(saveFilePath, resultsJson, { mode: 0o755 });
}

export async function failIfEmpty<T>(name: string, array: T[]) {
  await saveResults(name, array);
  expect(array.length).toBeTruthy();
}

export async function failIfEmptyHandler<T>(
  name: string,
  callback: () => Promise<Array<T>>,
) {
  const array = await callback();
  await failIfEmpty(name, array);
}
