// The bench's fixed structure: base, gantry, tray, bus bar, rails, ruler,
// the peer link and the two cables.
import { k, G } from "../kit.mjs";
import * as W from "../layout.mjs";
import { SOCKETS } from "../model.mjs";

export function benchOf(d) {
  const { P, at, planeOf, flat, S, L, D, box, byDepth, halo } = d;

  function plate() {
    const { PLATE, PLATE_H, FOOT_H } = W;
    const out = [`<path class="iso-halo" d="${k.haloOf(PLATE, -PLATE_H - FOOT_H, PLATE_H, P)}"/>`];
    for (const [x, y] of byDepth(k.corners(PLATE, 22))) {
      out.push(S(k.cylinder(x, y, 7, -PLATE_H - FOOT_H, 1.6, P, 28), { tone: "lo" }));
      out.push(S(k.cylinder(x, y, 5.4, -PLATE_H - FOOT_H + 1.6, FOOT_H - 1.6, P, 28), { tone: "mid" }));
    }
    out.push(S(k.slabOf(PLATE, -PLATE_H, PLATE_H, P, 8, 1.6), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(PLATE, 5), 0, P), { tone: "lo" }));
    const screws = k.corners(PLATE, 10);
    out.push(L(screws.map(([x, y]) => k.ring(x, y, 2.2, 0, P, 16)).join(""), { tone: "lo" }));
    out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.5 }));
    const label = { x: 150, y: 36, w: 40, d: 11, r: 1.2 };
    out.push(S(k.slabOf(label, 0, 0.8, P, 3), { tone: "lo", crease: "none" }));
    out.push(L(k.planOutline(k.insetPlan(label, 1.4), 0.8, P, 3), { tone: "faint" }));
    out.push(L([28, 22, 14].map((w, i) => k.lineOnTop([label.x + 4, label.y + 3 + i * 2.5], [label.x + 4 + w, label.y + 3 + i * 2.5], 0.8, P)).join(""), { tone: "lo", free: true }));
    out.push(D([at([label.x + label.w - 3, label.y + 2.6, 0.8]), at([label.x + label.w - 3, label.y + label.d - 2.6, 0.8])], { size: 0.45 }));
    return out.join("");
  }

  function post(x) {
    const { BEAM, BEAM_Z, POSTS } = W;
    const out = [];
    const foot = { x: x - 3, y: BEAM.y - 2, w: 14, d: 14, r: 1.5 };
    out.push(S(box(foot, 0, 2.2, 3, 0.5), { tone: "mid" }));
    out.push(D(k.corners(foot, 2.2).map(([px, py]) => at([px, py, 2.2])), { size: 0.45 }));
    const column = { x, y: BEAM.y + 1, w: 8, d: 8, r: 1 };
    out.push(S(box(column, 2.2, BEAM_Z - 2.2, 3, 0.4), { tone: "mid", inner: L(k.sideSeam(column, 12, P, 3), { tone: "faint" }) }));
    if (x === POSTS[1]) {
      // The heads' drive input, where the peer link's cable lands.
      const plug = { x: x + 1.6, y: column.y + column.d, w: 4.8, d: 1.6, r: 0.4 };
      out.push(S(box(plug, 11.4, 5.2, 2, 0.3), { tone: "mid" }));
      out.push(D([at([x + 2.6, plug.y + plug.d, 15.6]), at([x + 5.4, plug.y + plug.d, 12])], { size: 0.35 }));
    }
    return out.join("");
  }

  function gantry() {
    const { BEAM, BEAM_Z, BEAM_TOP, POSTS } = W;
    const out = [halo({ x: BEAM.x, y: BEAM.y, w: BEAM.w, d: BEAM.d, r: 2 }, 0, 6)];
    out.push(...POSTS.map(post));
    out.push(S(box(BEAM, BEAM_Z, BEAM_TOP - BEAM_Z, 3, 0.6), { tone: "mid", inner: L(k.sideSeam(BEAM, BEAM_Z + 2, P, 3), { tone: "faint" }) }));
    // A linear guide on the beam's top, with its end stops.
    const guide = { x: BEAM.x + 6, y: BEAM.y + 3.5, w: BEAM.w - 12, d: 3, r: 0.6 };
    out.push(S(box(guide, BEAM_TOP, 1.2, 2, 0.3), { tone: "mid", crease: "lo" }));
    out.push(D(Array.from({ length: 22 }, (_, i) => at([guide.x + 4 + i * ((guide.w - 8) / 21), guide.y + 1.5, BEAM_TOP + 1.2])), { size: 0.35, tone: "lo" }));
    for (const x of [BEAM.x + 1.5, BEAM.x + BEAM.w - 5.5]) {
      const stop = { x, y: BEAM.y + 1.5, w: 4, d: 7, r: 0.8 };
      out.push(S(box(stop, BEAM_TOP, 4, 2, 0.4), { tone: "mid" }));
      out.push(D([at([x + 2, BEAM.y + 5, BEAM_TOP + 4])], { size: 0.45 }));
    }
    return out.join("");
  }

  function tray() {
    const { TRAY, TRAY_Z, TRAY_TOP, X0, PITCH } = W;
    const out = [halo(k.insetPlan(TRAY, -3), 0, 5)];
    for (const [x, y] of byDepth(k.corners(TRAY, 7))) {
      out.push(S(box({ x: x - 4, y: y - 4, w: 8, d: 8, r: 1 }, 0, TRAY_Z, 2, 0.3), { tone: "lo" }));
    }
    out.push(S(box(TRAY, TRAY_Z, TRAY_TOP - TRAY_Z, 4, 0.8), { tone: "mid", inner: L(k.sideSeam(TRAY, TRAY_Z + 2.4, P, 4), { tone: "faint" }) }));
    const sockets = [];
    for (let i = 0; i < SOCKETS; i++) sockets.push(k.planOutline({ x: X0 + i * PITCH + 0.8, y: -10.6, w: PITCH - 1.6, d: 21.2, r: 0.8 }, TRAY_TOP, P, 2));
    out.push(L(sockets.join(""), { tone: "faint" }));
    // Every sixth socket has a mark on the back lip, as the ruler does.
    const marks = [];
    for (let i = 0; i <= SOCKETS; i += 6) marks.push(k.lineOnTop([X0 + i * PITCH, TRAY.y], [X0 + i * PITCH, -10.6], TRAY_TOP, P));
    out.push(L(marks.join(""), { tone: "lo" }));
    out.push(D([[TRAY.x + 3, -7], [TRAY.x + 3, 7], [TRAY.x + TRAY.w - 3, -7], [TRAY.x + TRAY.w - 3, 7]].map(([x, y]) => at([x, y, TRAY_TOP])), { size: 0.45 }));
    return out.join("");
  }

  function bus() {
    const { TRAY, BAR } = W;
    const out = [];
    for (let i = 0; i < 7; i++) {
      const x = TRAY.x + 6 + i * ((TRAY.w - 12) / 6);
      out.push(S(k.cylinder(x, BAR.y + BAR.d / 2, 1.3, 0, BAR.z, P, 14), { tone: "lo", inner: L(k.sideArc(x, BAR.y + BAR.d / 2, 1.3, 2, P, 8), { tone: "faint" }) }));
    }
    out.push(S(box({ x: TRAY.x, y: BAR.y, w: TRAY.w, d: BAR.d, r: 0.5 }, BAR.z, BAR.h, 2, 0.3), { tone: "mid", crease: "lo" }));
    return out.join("");
  }

  function rails() {
    const { TRAY, RAILS, RAIL_H } = W;
    const out = [];
    for (const y of RAILS) {
      out.push(S(box({ x: TRAY.x, y, w: TRAY.w, d: 2.4, r: 0.6 }, 0, RAIL_H, 2, 0.3), { tone: "mid" }));
      out.push(D([TRAY.x + 3, TRAY.x + TRAY.w - 3].map((x) => at([x, y + 1.2, RAIL_H])), { size: 0.35 }));
    }
    for (const x of [TRAY.x - 4, TRAY.x + TRAY.w]) {
      out.push(S(box({ x, y: RAILS[0] - 1.5, w: 4, d: RAILS[1] - RAILS[0] + 5.4, r: 1 }, 0, 5, 2, 0.4), { tone: "mid" }));
      out.push(D([at([x + 2, RAILS[0] + 1.2, 5]), at([x + 2, RAILS[1] + 1.2, 5])], { size: 0.4 }));
    }
    return out.join("");
  }

  function ruler() {
    const { RULER, X0, XE, PITCH } = W;
    const out = [];
    out.push(S(k.slabOf(RULER, 0, 0.6, P, 3), { tone: "lo", crease: "none" }));
    const ticks = k.topTicks(X0, XE, PITCH, 6, RULER.y, 0.6, [1.8, 3.4], P);
    out.push(L(ticks.minor, { tone: "lo" }), L(ticks.major, { tone: "mid" }));
    out.push(L(k.lineOnTop([X0, RULER.y], [X0, RULER.y + 4.4], 0.6, P), { tone: "hi" }));
    out.push(D([at([RULER.x + 1.6, RULER.y + 4.6, 0.6]), at([RULER.x + RULER.w - 1.6, RULER.y + 4.6, 0.6])], { size: 0.4 }));
    return out.join("");
  }

  // The peer link: one status lamp per connection, cabled to the gantry.
  function link() {
    const { LINK, LINK_TOP, LAMPS, lampX } = W;
    const out = [halo(k.insetPlan(LINK, -2), 0, 3)];
    out.push(S(box(LINK, 0, LINK_TOP, 4, 0.6), { tone: "mid", inner: L(k.sideSeam(LINK, 2.2, P, 4), { tone: "faint" }) }));
    out.push(D(k.corners(LINK, 2.4).map(([x, y]) => at([x, y, LINK_TOP])), { size: 0.45 }));
    out.push(L(k.planOutline({ x: LINK.x + 5, y: LINK.y + 4, w: 26, d: 7, r: 1 }, LINK_TOP, P, 3), { tone: "faint" }));
    out.push(L([20, 14].map((w, i) => k.lineOnTop([LINK.x + 7, LINK.y + 6 + i * 2.6], [LINK.x + 7 + w, LINK.y + 6 + i * 2.6], LINK_TOP, P)).join(""), { tone: "lo", free: true }));
    const face = LINK.y + LINK.d;
    out.push(`<g transform="${planeOf(face)}"><path class="iso-line" data-tone="faint" d="${flat(LINK.x + 5, 3.4, LINK.x + 40, 8.6, 1.4)}"/></g>`);
    for (let i = 0; i < LAMPS; i++) {
      const F = G.frameAlong([lampX(i), face, 6], [0, 1, 0]);
      out.push(S(G.disc(0, 0.8, 1.5, F, P), { tone: "mid" }));
      const [cx, cy] = at([lampX(i), face + 0.8, 6]);
      out.push(`<circle class="sv-lamp" data-part="lamp" cx="${cx.toFixed(2)}" cy="${cy.toFixed(2)}" r="0.9"/>`);
    }
    const gland = { x: LINK.x + LINK.w - 6, y: LINK.y + 6 };
    out.push(S(k.cylinder(gland.x, gland.y, 2, LINK_TOP, 2.4, P, 16), { tone: "mid" }));
    out.push(S(k.cylinder(gland.x, gland.y, 1.3, LINK_TOP + 2.4, 1.4, P, 14), { tone: "mid" }));
    return out.join("");
  }

  function linkCable() {
    const { LINK, LINK_TOP, POSTS, BEAM } = W;
    const from = [LINK.x + LINK.w - 6, LINK.y + 6, LINK_TOP + 3.8];
    const to = [POSTS[1] + 4, BEAM.y + 10.6, 14];
    return k.wireSvg(at(from), at(to), { via: [at([from[0], LINK.y + 2, LINK_TOP + 9]), at([POSTS[1] + 4, BEAM.y + 13, 16])], tone: "mid", size: 0.8 });
  }

  // From the bus bar's end to the monitor's input jack: the loopback endpoint.
  function cable() {
    const { TRAY, BAR, SIDE } = W;
    const from = [TRAY.x, BAR.y + BAR.d / 2, BAR.z + BAR.h / 2];
    const to = [SIDE + 3.4, -2, 9];
    return k.wireSvg(at(from), at(to), { via: [at([TRAY.x - 10, BAR.y + BAR.d / 2, 2]), at([SIDE + 12, 8, 2]), at([SIDE + 8, -2, 9])], tone: "mid", size: 0.9 });
  }

  return { plate, gantry, tray, bus, rails, ruler, link, linkCable, cable };
}
