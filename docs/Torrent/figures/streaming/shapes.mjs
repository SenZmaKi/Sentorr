// Shapes that change while the figure runs. Shared by the build and the page,
// so they take the kit's functions as `kit` rather than importing them.
import { PITCH, X0, TRAY, TRAY_TOP, BLOCK_H, COMB_Y, LANE } from "./layout.mjs";
import { SOCKETS, READY_S } from "./model.mjs";

const blockPlan = (i) => ({ x: X0 + i * PITCH + 1.3, y: -10, w: PITCH - 2.6, d: 20, r: 0.6 });

/** A piece in its socket, as tall as the share of it downloaded. */
export function blockSvg(kit, P, i, fill) {
  if (fill <= 0.001) return "";
  const done = fill >= 1;
  const paths = kit.slabOf(blockPlan(i), TRAY_TOP, Math.max(0.3, fill * BLOCK_H), P, 2, done ? 0.4 : 0);
  return kit.solidSvg(paths, { tone: done ? "hi" : "mid", crease: done ? "lo" : "faint" });
}

/** The comb: one tooth per urgent piece, stepped by its deadline. Local x 0 is the read. */
export function combSvg(kit, P, count) {
  const out = [];
  for (let i = 0; i < count; i++) {
    const x = i * PITCH;
    const h = 8 - (count > 1 ? i / (count - 1) : 0) * 5.6;
    const seg = { x: x - PITCH / 2 + 0.3, y: COMB_Y, w: PITCH - 0.6, d: 1.4, r: 0.3 };
    out.push(`<g data-part="tooth" data-tooth="${i}">`);
    out.push(kit.solidSvg(kit.slabOf(seg, 8, 1.6, P, 2, 0.2), { tone: "hi", lit: true }));
    out.push(kit.solidSvg(kit.slabOf({ x: x - 1.2, y: COMB_Y, w: 2.4, d: 1.2, r: 0.3 }, 9.6, h, P, 2, 0.2), { tone: "hi", lit: true }));
    out.push(`</g>`);
  }
  return out.join("");
}

/** The film's end: a divider after its last piece and a lid over the sockets past it. */
export function lidSvg(kit, P, pieces) {
  if (pieces >= SOCKETS) return "";
  const x = X0 + pieces * PITCH;
  const lid = { x: x + 1.2, y: TRAY.y + 2, w: TRAY.x + TRAY.w - 2 - x - 1.2, d: TRAY.d - 4, r: 1 };
  const divider = { x: x - 0.6, y: TRAY.y + 1, w: 1.8, d: TRAY.d - 2, r: 0.4 };
  const rule = kit.lineOnTop([lid.x, lid.y + lid.d / 2], [lid.x + lid.w, lid.y + lid.d / 2], TRAY_TOP + 0.8, P);
  return [
    kit.solidSvg(kit.slabOf(lid, TRAY_TOP, 0.8, P, 3, 0.3), { tone: "lo", inner: kit.lineSvg(rule, { tone: "faint" }) }),
    kit.solidSvg(kit.slabOf(divider, TRAY_TOP, 9, P, 2, 0.3), { tone: "mid" }),
    kit.dotsSvg([kit.iso([x + 0.3, TRAY.y + 3, TRAY_TOP + 9], P), kit.iso([x + 0.3, TRAY.y + TRAY.d - 3, TRAY_TOP + 9], P)], { size: 0.4 }),
  ].join("");
}

/**
 * mpv's cache as a strip on the ruler: from the playhead slider's front face
 * to the end of the verified run, at most 60 s. A tab rides [READY_S] ahead
 * of the position: playback starts or resumes once the strip passes it.
 * Positions are in seconds; [pieceS] is the playback each piece holds.
 */
export function stripSvg(kit, P, pos, cache, pieceS) {
  const xAt = (t) => X0 + (t / pieceS) * PITCH;
  const from = xAt(pos) + 3;
  const to = xAt(pos + cache);
  const out = [];
  if (to - from > 0.3) {
    out.push(kit.solidSvg(kit.slabOf({ x: from, y: LANE.y, w: to - from, d: LANE.d, r: 0.4 }, 0.6, 0.5, P, 2, 0.2), { tone: "hi", crease: "lo" }));
  }
  const tab = xAt(pos + READY_S);
  out.push(kit.solidSvg(kit.slabOf({ x: tab - 0.5, y: LANE.y - 0.5, w: 1, d: LANE.d + 1, r: 0.3 }, 0.6, 1.6, P, 2, 0.2), { tone: "mid" }));
  return out.join("");
}
