import { app } from "electron";
import { writeFile, readFile, stat } from "fs/promises";
import path from "path";
import { type Config } from "./types";
import { tryCatch, tryCatchAsync } from "@/common/functions";
import { beforeQuitTasks } from "../common/constants";
import { Resolution } from "../torrent/sources/common/types";
// import { rm } from "fs/promises";

export async function createConfigManager() {
  const configFilePath = path.join(app.getPath("userData"), "config.json");
  console.log("configFilePath:", configFilePath);
  // await rm(configFilePath);
  let writePromise: Promise<void> | undefined = undefined;

  async function loadConfig() {
    const [statResult, statError] = await tryCatchAsync(stat(configFilePath));
    if (statError) return undefined;
    if (!statResult.isFile()) return undefined;

    const configString = await readFile(configFilePath, "utf8");
    console.log("configString:", configString);
    const [parseResult, parseError] = tryCatch(() => JSON.parse(configString));
    if (parseError) {
      console.error(`Failed to parse config file: ${parseError}`);
      return undefined;
    }
    return parseResult as Config;
  }

  async function saveConfig() {
    // Avoid writing the config file if it's already being written
    if (writePromise) await writePromise;
    const configString = JSON.stringify(config, null, 4);
    writePromise = writeFile(configFilePath, configString);
    // Ensure that the config file is fully written before the app is quit
    beforeQuitTasks.push(writePromise);
    await writePromise;
    beforeQuitTasks.splice(beforeQuitTasks.indexOf(writePromise), 1);
  }
  async function getConfig() {
    return config;
  }

  async function setConfig(newConfig: Config) {
    config = newConfig;
    await saveConfig();
  }

  function defaultConfig(): Config {
    return {
      torrent: {
        serverPort: 0,
        torrentPort: 0,
        maxConns: 50,
        maxTorrentStreams: 5,
        torrentTimeoutSecs: 10,
      },
      player: {
        continueRewindSecs: 5,
        volume: 0.8,
        muted: false,
        playbackRate: 1,
        resolution: Resolution.R1080P,
        strictResolution: false,
      },
      allMediaProgress: {
        current: undefined,
        mediaProgress: {},
      },
    };
  }

  let config = (await loadConfig()) ?? defaultConfig();
  await saveConfig();
  return { setConfig, getConfig };
}

const configManager = await createConfigManager();
export default configManager;
