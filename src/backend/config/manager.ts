import { app } from "electron/main";
import { writeFile, readFile, stat } from "fs/promises";
import path from "path";
import { type Config } from "./types";
// import { rm } from "fs/promises";

export async function createConfigManager() {
  const configFilePath = path.join(app.getPath("userData"), "config.json");
  console.log("configFilePath:", configFilePath);
  // await rm(configFilePath);

  async function loadConfig() {
    try {
      const statResult = await stat(configFilePath);
      if (!statResult.isFile()) {
        return undefined;
      }

      const configString = await readFile(configFilePath, "utf8");
      try {
        return JSON.parse(configString) as Config;
      } catch (parseError) {
        console.error(`Failed to parse config file: ${parseError}`);
        return undefined;
      }
    } catch (error: any) {
      if (error.code === "ENOENT") {
        return undefined;
      } else {
        throw error;
      }
    }
  }

  async function saveConfig() {
    const configString = JSON.stringify(config, null, 4);
    await writeFile(configFilePath, configString);
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
