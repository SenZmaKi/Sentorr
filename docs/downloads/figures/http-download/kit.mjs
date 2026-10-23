// The anatomy-refined skill's kit and explorer (ANATOMY_HOME or local dev repo).
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const CANDIDATES = [
  process.env.ANATOMY_HOME,
  join(homedir(), "Dev/anatomy-refined"),
  join(homedir(), ".agents/skills/anatomy-refined"),
].filter(Boolean);

const HOME = CANDIDATES.find((p) => existsSync(p)) ?? CANDIDATES[0];
const load = (path) => import(pathToFileURL(join(HOME, path)).href);

export const k = await load("kit/iso-kit.mjs");
export const G = await load("kit/lathe.mjs");
export const { kitScript } = await load("scripts/inline-kit.mjs");
export const {
  panelHtml,
  stagesHtml,
  notesHtml,
  legendHtml: partsHtml,
  thumbSvg,
  highlightCss,
  EXPLORER_CSS,
  explorerScript,
} = await load("kit/explorer.mjs");
