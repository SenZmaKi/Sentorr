// The parts legend: each entry is a crop of the real bench in the figure's own
// camera, and says what the part stands for. `stat` slots fill in live.
import { k } from "./kit.mjs";
import * as W from "./layout.mjs";
import { SOCKETS } from "./model.mjs";
import { REST, sceneOf } from "./scene.mjs";
import { CAMERA } from "./camera.mjs";
import { thumbSvg, partsHtml as listHtml } from "./kit.mjs";

const span = (x0, x1, y0, y1, z0, z1) => k.boxCorners({ x: x0, y: y0, w: x1 - x0, d: y1 - y0, r: 0 }, z0, z1);
const stat = (id) => `<span data-stat="${id}"></span>`;

export const ENTRIES = [
  {
    key: "reader",
    name: "Read carriage and lit comb",
    text: `Where mpv's HTTP read is waiting: the first missing piece. The comb covers the urgent window, ${stat("urgent")}, at top priority, one tooth per deadline, ${stat("step")} apart.`,
    view: span(W.cellX(4), W.cellX(12), 12, 36, 0, 18),
    draw: ["pieces", "reader", "bus"],
  },
  {
    key: "pieces",
    name: "Tray and blocks",
    text: `The film's pieces, ${stat("piece")}. A full block is downloaded and hash-verified; a short one is still arriving.`,
    view: span(W.cellX(3), W.cellX(10), -12, 14, 0, 17),
    draw: ["pieces"],
  },
  {
    key: "heads",
    name: "Print heads",
    text: "Peer connections. Each fetches one piece; the fastest take the soonest deadlines, and idle ones park at the right end of the beam.",
    view: span(W.cellX(4), W.cellX(10), -44, 2, 12, 50),
    draw: ["pieces", "heads"],
  },
  {
    key: "peers",
    name: "Peer-link lamps",
    text: "One lamp per peer, lit while that peer is sending. Dark lamps are peers switched off in Network.",
    view: span(W.LINK.x - 2, W.LINK.x + W.LINK.w + 2, W.LINK.y - 2, W.LINK.y + W.LINK.d + 2, 0, W.LINK_TOP + 4),
    draw: ["peers"],
  },
  {
    key: "playhead",
    name: "Slider on the ruler",
    text: `The playback position. The download-ahead window covers ${stat("ahead")} from here.`,
    view: span(W.X0 + 1, W.X0 + 8 * W.PITCH, 37, 50, 0, 4),
    draw: ["playhead"],
  },
  {
    key: "strip",
    name: "Cache strip and 2 s tab",
    text: "The video mpv has ready: from the playhead to the first missing piece, up to 60 s. Playback starts or resumes only once the strip passes the tab.",
    view: span(W.X0 + 1, W.X0 + 9 * W.PITCH, 37, 50, 0, 4),
    draw: ["playhead", "strip"],
    state: { position: 1.2, cache: 7 },
  },
  {
    key: "bus",
    name: "Bus bar and cable",
    text: "The loopback HTTP endpoint mpv reads from. It serves only verified pieces.",
    view: span(W.SIDE - 4, W.X0 + 8, -6, 24, 0, 12),
    draw: ["bus", "pieces", "player"],
  },
  {
    key: "player",
    name: "Monitor",
    text: "mpv playing the stream. Its seek bar shows what has played and what is cached; three dots mean it is waiting for data.",
    view: span(W.MON.x - 2, W.MON.x + W.MON.w + 2, W.MON.y - 14, W.FRONT + 2, 0, W.MON_TOP),
    draw: ["player"],
  },
  {
    key: "lid",
    name: "Divider and lid",
    text: "The film's end. The sockets past it are not part of this film.",
    view: span(W.X0 + 27 * W.PITCH, W.X0 + 33 * W.PITCH, -14, 14, 0, 19),
    draw: ["pieces", "lid"],
    state: { pieces: 30, fills: REST.fills.map((_, i) => (i >= 26 && i < 30 ? 1 : 0)) },
  },
];

export const KEYS = ENTRIES.map((e) => e.key);

export function legendHtml() {
  return listHtml(
    ENTRIES.map((entry) => {
      const state = { ...REST, ...(entry.state ?? {}) };
      if (entry.key !== "heads") state.heads = state.heads.map(() => SOCKETS + 40);
      return { ...entry, thumb: thumbSvg({ view: entry.view, camera: CAMERA, body: (P) => sceneOf(P, state, entry.draw) }) };
    }),
  );
}
