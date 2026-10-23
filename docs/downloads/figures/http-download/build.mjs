// HTTP Download Engine bench, with its explorer. node build.mjs [--light]
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
const HEIGHT = 280;

const P = k.fitProjection(
  [
    ...k.boxCorners(W.PLATE, -W.PLATE_H - W.FOOT_H, 0),
    ...k.boxCorners(W.GANTRY_BEAM, W.GANTRY_Z, W.GANTRY_TOP + 8),
    ...k.boxCorners(W.PROBE_BOX, 0, W.PROBE_TOP + 4),
    ...k.boxCorners(W.LEDGER_BOX, 0, W.LEDGER_TOP + 8),
    ...k.boxCorners(W.GAUGE_BOX, 0, W.GAUGE_TOP + 4),
  ],
  WIDTH,
  HEIGHT,
  { pad: 16, ...CAMERA }
);

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label:
    "An HTTP Download Engine bench. A slotted cassette bed holds a file partitioned into parallel byte ranges. Overhead feed heads stream chunks across multiple concurrent HTTP 206 connections. An indexing carriage on a lead screw (the serialized offset file writer) directs data to the exact disk byte offset. An anvil probe verifies initial HTTP Range support, while a notary tape reel stamps SHA-256 block checkpoints for resume recovery.",
  body: sceneOf(P),
});

const plate = k.plateHtml({
  fig: "Fig 1",
  title: "HTTP Download Engine",
  hint: "Space pauses · Click explorer controls or actions to test",
  readout: "starting · 0.0 / 64.0 MB · 8.0 MB/s",
  body: `<div class="iso-stage" tabindex="0" role="slider" aria-label="HTTP Download Engine bench" aria-valuemin="0" aria-valuemax="31" aria-valuenow="0">${svg}</div>`,
});

const lead = `<p class="tb-lead">How Senpwai and Sentorr assemble multi-connection HTTP downloads: parallel workers fetch chunks via <code>206 Partial Content</code>, a single serialized <code>_OffsetFileWriter</code> commits them to disk without race conditions, and 1&nbsp;MiB SHA-256 block checkpoints guarantee safe recovery.</p>`;
const body = lead + plate.replace("</figure>", `${explorerHtml()}${legendHtml()}${notes()}</figure>`);

// The page script: the kit and explorer, then the model and shapes in their own scope.
const source = (file) =>
  readFileSync(join(HERE, file), "utf8")
    .replace(/^import[\s\S]*?;\n/gm, "")
    .replace(/^export /gm, "");

const live = `{\n${["model.mjs", "layout.mjs", "shapes.mjs"].map(source).join("\n")}\nconst P = ${JSON.stringify(P)};\nconst PRESETS = ${JSON.stringify(PRESETS)};\n${readFileSync(join(HERE, "live.js"), "utf8")}\n}`;

const css = [readFileSync(join(HERE, "style.css"), "utf8"), EXPLORER_CSS, highlightCss(KEYS)].join("\n");
const name = theme === "light" ? "http-download-light.html" : "http-download.html";

writeFileSync(
  join(HERE, name),
  k.pageHtml({
    title: "HTTP Download Engine",
    theme,
    body: `<style>${css}</style>${body}`,
    script: kitScript() + explorerScript() + live,
    width: 900,
  })
);
console.log("wrote", name);
