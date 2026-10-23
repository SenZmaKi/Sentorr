// The anatomy-refined skill's kit and explorer (ANATOMY_HOME, default
// ~/.agents/skills/anatomy-refined, where `npx skills add -g` installs it).
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const HOME = process.env.ANATOMY_HOME ?? join(homedir(), ".agents/skills/anatomy-refined");
const load = (path) => import(pathToFileURL(join(HOME, path)).href);

export const k = await load("kit/iso-kit.mjs");
export const G = await load("kit/lathe.mjs");
export const { kitScript } = await load("scripts/inline-kit.mjs");
export const { panelHtml, stagesHtml, notesHtml, legendHtml: partsHtml, thumbSvg, highlightCss, EXPLORER_CSS, explorerScript } = await load("kit/explorer.mjs");
