// The parts that report or move: monitor, print heads, read carriage,
// and the playhead slider.
import { k, G } from "../kit.mjs";
import * as W from "../layout.mjs";

export function instrumentsOf(d) {
  const { P, at, planeOf, flat, recess, S, L, D, box, halo } = d;

  function screen() {
    const { CRT, FRONT } = W;
    const { x0, x1, z0, z1 } = CRT;
    const scan = [];
    for (let z = z0 + 1.2; z < z1; z += 1.4) scan.push(`M${x0} ${(-z).toFixed(1)}H${x1}`);
    const hills = `M${x0} ${-(z0 + 8)}C${x0 + 6} ${-(z0 + 12)} ${x0 + 11} ${-(z0 + 10)} ${x0 + 16} ${-(z0 + 9)}S${x0 + 27} ${-(z0 + 12.5)} ${x1} ${-(z0 + 9.5)}V${-(z0 + 4.6)}H${x0}Z`;
    const bar = { from: x0 + 3, to: x1 - 3, z: z0 + 2.6 };
    const back = [
      `<path class="sv-glow" d="${flat(x0 + 2, z0 + 2, x1 - 2, z1 - 2, 6)}"/>`,
      `<g data-part="picture"><circle class="sv-sun" data-part="sun" cx="${x0 + 8}" cy="${-(z0 + 14.5)}" r="2.6"/><path class="sv-hills" d="${hills}"/></g>`,
      `<path class="sv-scan" d="${scan.join("")}"/>`,
      `<path class="sv-letterbox" d="M${x0} ${-z1}H${x1}V${-(z1 - 2.4)}H${x0}ZM${x0} ${-(z0 + 4.6)}H${x1}V${-z0}H${x0}Z"/>`,
      `<path class="sv-track" d="M${bar.from} ${-bar.z}H${bar.to}"/>`,
      `<path class="sv-cached" data-part="cached" d="M${bar.from} ${-bar.z}H${bar.from + 9}"/>`,
      `<path class="sv-played" data-part="played" d="M${bar.from} ${-bar.z}H${bar.from + 6}"/>`,
      `<circle class="sv-head" data-part="screen-head" cx="${bar.from + 6}" cy="${-bar.z}" r="0.9"/>`,
      `<g data-part="spinner" style="opacity:0">${[-2.6, 0, 2.6].map((dx) => `<circle class="sv-dot" cx="${(x0 + x1) / 2 + dx}" cy="${-(z0 + z1) / 2 - 1}" r="0.8"/>`).join("")}</g>`,
    ].join("");
    return recess({ ...CRT }, FRONT, back, "sv-glass");
  }

  const knob = (x, z) => {
    const F = G.frameAlong([x, W.FRONT, z], [0, 1, 0]);
    return [
      S(G.disc(0, 1.2, 2.6, F, P), { tone: "mid" }),
      S(G.disc(1.2, 2.8, 2, F, P), { tone: "mid" }),
      L(G.ribsOf(F, 1.2, 2.8, 2, 18, P, { seams: "last" }), { tone: "lo" }),
      L(G.circleOf(F, 2.8, 0.6, P, 16), { tone: "lo" }),
    ].join("");
  };

  function monitor() {
    const { MON, MON_Z, MON_TOP, FRONT, SIDE, CRT } = W;
    const out = [halo(k.insetPlan(MON, -4), 0, 6)];
    const plinth = { x: MON.x - 2, y: MON.y - 14, w: MON.w + 4, d: MON.d + 16, r: 2 };
    out.push(S(box(plinth, 0, MON_Z, 4, 0.6), { tone: "mid" }));
    out.push(D(k.corners(plinth, 2.6).map(([x, y]) => at([x, y, MON_Z])), { size: 0.45 }));
    // The tube's housing tapers out of the back of the case.
    const neck = { x: MON.x + 7, y: MON.y - 12, w: MON.w - 14, d: 14, r: 4 };
    out.push(S(box(neck, MON_Z, 26, 6, 0.6), { tone: "mid", inner: L(k.sideSeam(neck, MON_Z + 13, P, 6), { tone: "faint" }) }));
    out.push(S(box({ x: neck.x + 6, y: neck.y - 4, w: neck.w - 12, d: 6, r: 2 }, MON_Z + 6, 14, 4, 0.4), { tone: "mid" }));
    out.push(S(box(MON, MON_Z, MON_TOP - MON_Z, 6, 1), { tone: "mid", inner: L(k.sideSeam(MON, MON_Z + 3, P, 6), { tone: "faint" }) }));
    // Vents: closed slots across the lid.
    const slots = [];
    for (let i = 0; i < 7; i++) slots.push(k.planOutline({ x: MON.x + 8 + i * 4.6, y: MON.y + 6, w: 1.6, d: 16, r: 0.8 }, MON_TOP, P, 3));
    out.push(L(slots.join(""), { tone: "lo" }));
    out.push(D([[MON.x + 4, MON.y + 4], [MON.x + MON.w - 4, MON.y + 4], [MON.x + 4, FRONT - 4], [MON.x + MON.w - 4, FRONT - 4]].map(([x, y]) => at([x, y, MON_TOP])), { size: 0.45 }));
    out.push(`<g transform="${planeOf(FRONT)}"><path class="iso-line" data-tone="faint" d="${flat(CRT.x0 - 2.4, CRT.z0 - 2.4, CRT.x1 + 2.4, CRT.z1 + 2.4, 4.6)}"/></g>`);
    out.push(screen());
    out.push(knob(-229, 9.4), knob(-222, 9.4));
    out.push(`<g transform="${planeOf(FRONT)}"><path class="iso-line" data-tone="faint" d="${flat(-214, 7.6, -202, 11.2, 1.6)}"/><path class="iso-line" data-tone="lo" d="M-212 ${-9.4}H-204" data-free="both"/></g>`);
    const [px, py] = at([-197, FRONT, 9.4]);
    out.push(`<circle class="sv-power" cx="${px}" cy="${py}" r="0.9"/>`);
    // Input jack on the side the cable comes in from.
    const jack = G.frameAlong([SIDE, -2, 9], [1, 0, 0]);
    out.push(S(G.disc(0, 1.6, 2.4, jack, P), { tone: "mid" }), S(G.disc(1.6, 3.4, 1.4, jack, P), { tone: "mid" }));
    out.push(L(G.circleOf(jack, 3.4, 0.5, P, 12), { tone: "lo" }));
    return out.join("");
  }

  // A print head, built at x = 0: one peer connection.
  function head() {
    const { BEAM, BEAM_Z, BEAM_TOP, NOZZLE_Y, TIP_Z } = W;
    const out = [];
    out.push(S(box({ x: -3.2, y: BEAM.y - 1, w: 6.4, d: BEAM.d + 2, r: 0.8 }, BEAM_TOP - 1, 4.4, 2, 0.4), { tone: "mid" }));
    out.push(D([at([-1.6, BEAM.y + 1.5, BEAM_TOP + 3.4]), at([1.6, BEAM.y + BEAM.d - 1.5, BEAM_TOP + 3.4])], { size: 0.4 }));
    out.push(S(box({ x: -3.2, y: BEAM.y + BEAM.d + 1, w: 6.4, d: 2, r: 0.5 }, BEAM_Z - 1, BEAM_TOP + 3.4 - (BEAM_Z - 1), 2, 0.3), { tone: "mid" }));
    const arm = { x: -1.5, y: BEAM.y + BEAM.d + 3, w: 3, d: NOZZLE_Y + 1.6 - (BEAM.y + BEAM.d + 3), r: 0.6 };
    out.push(S(box(arm, BEAM_TOP - 3, 3, 2, 0.3), { tone: "mid" }));
    out.push(S(k.cylinder(0, NOZZLE_Y, 1.7, BEAM_TOP - 9, 6, P, 18), { tone: "mid" }));
    out.push(S(k.cylinder(0, NOZZLE_Y, 1.1, TIP_Z + 8, BEAM_TOP - 9 - TIP_Z - 8, P, 16), { tone: "mid", crease: "none", inner: L(k.sideArc(0, NOZZLE_Y, 1.1, TIP_Z + 12, P, 10), { tone: "faint" }) }));
    out.push(S(box({ x: -2.4, y: NOZZLE_Y - 2.4, w: 4.8, d: 4.8, r: 0.6 }, TIP_Z + 2.2, 5.8, 2, 0.3), { tone: "mid" }));
    out.push(D([at([2.4, NOZZLE_Y, TIP_Z + 5.1])], { size: 0.35, tone: "lo" }));
    out.push(S(k.cylinder(0, NOZZLE_Y, 0.8, TIP_Z, 2.2, P, 12), { tone: "mid" }));
    return out.join("");
  }

  // The read carriage, built at x = 0: the piece mpv's HTTP read waits on.
  // Its comb (`comb`) runs ahead over the urgent window.
  function carriage(comb = "") {
    const { RAILS, RAIL_H, BAR, COMB_Y } = W;
    const out = [halo({ x: -6, y: 20, w: 12, d: 14, r: 2 }, RAIL_H, 2)];
    const base = { x: -6, y: RAILS[0] - 1.2, w: 12, d: RAILS[1] - RAILS[0] + 4.8, r: 1.4 };
    for (const y of RAILS) out.push(S(box({ x: -5.2, y: y - 0.6, w: 10.4, d: 3.6, r: 0.6 }, RAIL_H, 1.2, 2, 0.2), { tone: "lo" }));
    out.push(S(box(base, RAIL_H + 1.2, 3, 3, 0.5), { tone: "mid" }));
    out.push(D(k.corners(base, 1.8).map(([x, y]) => at([x, y, RAIL_H + 4.2])), { size: 0.4 }));
    out.push(S(box({ x: -3.5, y: RAILS[0] - 1.2, w: 7, d: 5, r: 0.8 }, RAIL_H + 4.2, 10 - RAIL_H - 4.2, 2, 0.3), { tone: "mid" }));
    // The collector shoe rides the bus bar.
    out.push(S(box({ x: -1.2, y: BAR.y + 0.1, w: 2.4, d: BAR.d - 0.2, r: 0.3 }, BAR.z + BAR.h, 1, 2), { tone: "lo" }));
    out.push(S(box({ x: -1.6, y: COMB_Y + 1.4, w: 3.2, d: RAILS[0] - 1.2 - COMB_Y - 1.4, r: 0.4 }, 8, 2, 2, 0.3), { tone: "mid" }));
    out.push(L(k.lineOnTop([0, RAILS[0] - 1.2], [0, RAILS[0] + 3.8], 10, P), { tone: "hi" }));
    out.push(`<g data-part="comb">${comb}</g>`);
    return out.join("");
  }

  // The playback position: a slider on the ruler, built at x = 0.
  function playhead() {
    const { RULER } = W;
    const body = { x: -3, y: RULER.y - 1.4, w: 6, d: RULER.d + 2.8, r: 0.8 };
    return [
      S(box(body, 0.6, 2.4, 2, 0.3), { tone: "mid" }),
      L(k.lineOnTop([0, body.y], [0, body.y + body.d], 3, P), { tone: "hi" }),
      S(box({ x: -2.2, y: body.y + body.d, w: 4.4, d: 2, r: 0.5 }, 0.6, 1.8, 2, 0.2), { tone: "mid" }),
    ].join("");
  }


  return { monitor, head, carriage, playhead };
}
