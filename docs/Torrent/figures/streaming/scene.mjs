// The whole bench in painter's order, each item tagged with the legend key it
// belongs to. The figure draws every key; a legend thumbnail draws a few.
import { k } from "./kit.mjs";
import * as W from "./layout.mjs";
import { SOCKETS, MAX_PEERS, DEFAULTS, derive, parkOf } from "./model.mjs";
import { drawOf } from "./parts/draw.mjs";
import { benchOf } from "./parts/bench.mjs";
import { instrumentsOf } from "./parts/instruments.mjs";
import { blockSvg, combSvg, lidSvg, stripSvg } from "./shapes.mjs";

const kit = k;
const { PIECE_S } = derive(DEFAULTS);

/** A resting state: what the figure shows before its script starts. */
export const REST = {
  fills: Array.from({ length: SOCKETS }, (_, i) => (i < 6 ? 1 : i < 9 ? [0.6, 0.35, 0.15][i - 6] : 0)),
  heads: Array.from({ length: MAX_PEERS }, (_, i) => (i < 3 ? 6 + i : parkOf(i))),
  busy: [true, true, true, false, false, false],
  reader: 6,
  urgent: 5,
  pieces: SOCKETS,
  position: 4.2, // in pieces
  cache: 3,
};

export function sceneOf(P, state = REST, only = null) {
  const d = drawOf(P);
  const b = benchOf(d);
  const m = instrumentsOf(d);
  const items = [];
  const put = (key, svg) => {
    if (!only || only.includes(key)) items.push(`<g data-key="${key}">${svg}</g>`);
  };
  const { TRAY_TOP, BLOCK_H, NOZZLE_Y, TIP_Z, cellX } = W;

  put("base", b.plate());
  put("heads", b.gantry());
  put("player", m.monitor());
  put("pieces", b.tray() + state.fills.map((f, i) => `<g data-part="block" data-i="${i}">${blockSvg(kit, P, i, f)}</g>`).join(""));
  put("lid", `<g data-part="lid">${lidSvg(kit, P, state.pieces)}</g>`);
  const heads = state.heads.map((x, i) => {
    const on = state.busy[i] && state.fills[Math.round(x)] < 1;
    const top = TRAY_TOP + Math.max(0.3, (state.fills[Math.round(x)] ?? 0) * BLOCK_H);
    const tip = d.at([cellX(x), NOZZLE_Y, TIP_Z]);
    const end = d.at([cellX(x), NOZZLE_Y, top]);
    return [
      `<g data-part="filament" data-i="${i}"${on ? "" : ` display="none"`}>`,
      `<path class="iso-line" data-tone="lo" d="${k.pathOf([tip, end])}" style="stroke-width:0.9"/>`,
      `<g class="iso-dots" data-tone="hi"><circle r="0.7" cx="${end[0].toFixed(2)}" cy="${end[1].toFixed(2)}"/></g></g>`,
      `<g data-part="head" data-i="${i}" transform="${d.move([cellX(x), 0, 0])}">${m.head()}</g>`,
    ].join("");
  });
  put("heads", heads.join(""));
  put("peers", b.link() + b.linkCable());
  put("bus", b.bus());
  put("reader", b.rails() + `<g data-part="carriage" transform="${d.move([cellX(state.reader), 0, 0])}">${m.carriage(combSvg(kit, P, state.urgent))}</g>`);
  put("bus", b.cable());
  put("playhead", b.ruler());
  put("strip", `<g data-part="strip">${stripSvg(kit, P, state.position * PIECE_S, state.cache, PIECE_S)}</g>`);
  put("playhead", `<g data-part="playhead" transform="${d.move([W.X0 + state.position * W.PITCH, 0, 0])}">${m.playhead()}</g>`);
  return items.join("");
}
