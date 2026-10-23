// Torrent streaming bench, with its explorer. node build.mjs [--light]
// The reference for kit/explorer.mjs: legend of real parts, an in-depth panel,
// live stats, the algorithm's stages and the model's simplifications.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { k, kitScript, EXPLORER_CSS, explorerScript, highlightCss } from "./kit.mjs";
import * as W from "./layout.mjs";
import { CAMERA } from "./camera.mjs";
import { sceneOf } from "./scene.mjs";
import { legendHtml, KEYS } from "./legend.mjs";
import { explorerHtml, notes, PRESETS } from "./panel.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const theme = process.argv.includes("--light") ? "light" : "dark";
const WIDTH = 640;
const HEIGHT = 272;

const P = k.fitProjection(
  [...k.boxCorners(W.PLATE, -W.PLATE_H - W.FOOT_H, 0), ...k.boxCorners(W.BEAM, W.BEAM_Z, W.BEAM_TOP + 8), ...k.boxCorners(W.MON, 0, W.MON_TOP)],
  WIDTH,
  HEIGHT,
  { pad: 16, ...CAMERA },
);

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label:
    "A streaming bench. A tray of sockets holds a film as torrent pieces. Print heads on an overhead gantry, one per peer, deposit pieces into the sockets: first those under the lit comb on the read carriage, which marks mpv's HTTP read and the engine's urgent window, then the rest ahead of the playhead, rarest first. A slider on the ruler marks the playback position, a strip from it to the first missing piece shows the seconds of video mpv has ready, and a bus bar and cable carry the bytes to a small monitor.",
  body: sceneOf(P),
});

const plate = k.plateHtml({
  fig: "Fig 1",
  title: "Streaming a torrent",
  hint: "Click the tray to seek · Space pauses",
  readout: "starting · 0.0 s · cache 0.0 s · 0.0 MB/s",
  body: `<div class="iso-stage" tabindex="0" role="slider" aria-label="Torrent streaming bench: click a socket or use arrow keys to seek, Space to pause" aria-valuemin="0" aria-valuemax="35" aria-valuenow="0">${svg}</div>`,
});

const lead = `<p class="tb-lead">How Sentorr streams a torrent: the player reads a local HTTP endpoint while the engine decides which pieces the peers fetch first. Change the swarm, the film or the setting below and watch the bench re-plan.</p>`;
const body = lead + plate.replace("</figure>", `${explorerHtml()}${legendHtml()}${notes()}</figure>`);

// The page script: the kit and explorer, then the model and shapes in their own scope.
const source = (file) => readFileSync(join(HERE, file), "utf8").replace(/^import[\s\S]*?;\n/gm, "").replace(/^export /gm, "");
const live = `{\n${["model.mjs", "layout.mjs", "shapes.mjs"].map(source).join("\n")}\nconst P = ${JSON.stringify(P)};\nconst PRESETS = ${JSON.stringify(PRESETS)};\n${readFileSync(join(HERE, "live.js"), "utf8")}\n}`;

const css = [readFileSync(join(HERE, "style.css"), "utf8"), EXPLORER_CSS, highlightCss(KEYS)].join("\n");
const name = theme === "light" ? "torrent-stream-light.html" : "torrent-stream.html";
writeFileSync(join(HERE, name), k.pageHtml({ title: "Torrent streaming", theme, body: `<style>${css}</style>${body}`, script: kitScript() + explorerScript() + live, width: 900 }));
console.log("wrote", name);
