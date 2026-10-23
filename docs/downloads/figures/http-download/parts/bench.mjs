// The structural bench of the HTTP Download Engine.
import { k } from "../kit.mjs";
import * as W from "../layout.mjs";
import { SLOTS } from "../model.mjs";

export function benchOf(d) {
  const { P, S, L, D, box, at } = d;

  function plate() {
    const out = [];
    // Soft drop halo under the heavy plate
    out.push(d.halo(W.PLATE, -W.PLATE_H - W.FOOT_H, 6));

    // Rubber damper feet
    const feet = [
      [W.PLATE.x + 16, W.PLATE.y + 16],
      [W.PLATE.x + W.PLATE.w - 16, W.PLATE.y + 16],
      [W.PLATE.x + 16, W.PLATE.y + W.PLATE.d - 16],
      [W.PLATE.x + W.PLATE.w - 16, W.PLATE.y + W.PLATE.d - 16],
    ];
    for (let [fx, fy] of feet) {
      out.push(
        S(
          box({ x: fx - 8, y: fy - 8, w: 16, d: 16, r: 4 }, -W.PLATE_H - W.FOOT_H, W.FOOT_H, 4, 0.4),
          { tone: "lo", crease: "faint" }
        )
      );
    }

    // Heavy cast iron base plate
    out.push(
      S(box(W.PLATE, -W.PLATE_H, W.PLATE_H, 6, 1.2), {
        tone: "lo",
        crease: "mid",
      })
    );

    // Corner fixing screws
    const screws = [
      [W.PLATE.x + 8, W.PLATE.y + 8],
      [W.PLATE.x + W.PLATE.w - 8, W.PLATE.y + 8],
      [W.PLATE.x + 8, W.PLATE.y + W.PLATE.d - 8],
      [W.PLATE.x + W.PLATE.w - 8, W.PLATE.y + W.PLATE.d - 8],
    ];
    out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.55 }));

    // Engraved datum line around perimeter
    const margin = 5;
    const ring = k.roundedPlan(
      {
        x: W.PLATE.x + margin,
        y: W.PLATE.y + margin,
        w: W.PLATE.w - margin * 2,
        d: W.PLATE.d - margin * 2,
        r: W.PLATE.r - 2,
      },
      8
    );
    out.push(L(k.pathOf(ring.map(([x, y]) => at([x, y, 0])), true), { tone: "faint" }));

    return out.join("");
  }

  function cassetteTray() {
    const out = [];
    // Tray riser block
    out.push(
      S(box(W.TRAY, 0, W.TRAY_TOP, 3, 0.6), {
        tone: "mid",
        crease: "lo",
      })
    );

    // Pocket grid rules for the 32 slots
    for (let i = 0; i <= SLOTS; i++) {
      const x = W.X0 + i * W.PITCH;
      const line = k.lineOnTop([x, W.TRAY.y + 1], [x, W.TRAY.y + W.TRAY.d - 1], W.TRAY_TOP, P);
      out.push(L(line, { tone: i % 4 === 0 ? "mid" : "faint" }));
    }

    return out.join("");
  }

  function gantry() {
    const out = [];
    // Gantry vertical upright posts
    for (let px of W.POSTS) {
      // Flange foot
      out.push(
        S(box({ x: px - 5, y: W.GANTRY_Y - 5, w: 10, d: 10, r: 2 }, 0, 3, 3, 0.4), {
          tone: "mid",
          crease: "faint",
        })
      );
      // Upright post
      out.push(
        S(box({ x: px - 3, y: W.GANTRY_Y - 3, w: 6, d: 6, r: 1 }, 3, W.GANTRY_TOP - 3, 3, 0.3), {
          tone: "mid",
          crease: "lo",
        })
      );
      // Post mounting cap screws
      out.push(D([at([px, W.GANTRY_Y, W.GANTRY_TOP])], { size: 0.5 }));
    }

    // Overhead horizontal traverse beam
    out.push(
      S(box(W.GANTRY_BEAM, W.GANTRY_Z, 6, 3, 0.5), {
        tone: "mid",
        crease: "hi",
      })
    );

    // Machined center slot on top of the beam running edge-to-edge
    const slotY = W.GANTRY_Y;
    const slotLine = k.lineOnTop(
      [W.GANTRY_BEAM.x, slotY],
      [W.GANTRY_BEAM.x + W.GANTRY_BEAM.w, slotY],
      W.GANTRY_TOP,
      P
    );
    out.push(L(slotLine, { tone: "faint" }));

    return out.join("");
  }

  function leadScrewAndRails() {
    const out = [];
    // Chrome lead screw rod and guide rails drawn first, then capped by blocks
    const screwA = at([W.X0 - 8, W.LEAD_SCREW_Y, W.LEAD_SCREW_Z]);
    const screwB = at([W.XE + 8, W.LEAD_SCREW_Y, W.LEAD_SCREW_Z]);
    out.push(`<path class="iso-line" data-tone="hi" d="${k.pathOf([screwA, screwB])}" style="stroke-width:2.2"/>`);

    for (let ry of W.RAILS) {
      const p1 = at([W.X0 - 8, ry, 2.5]);
      const p2 = at([W.XE + 8, ry, 2.5]);
      out.push(`<path class="iso-line" data-tone="lo" d="${k.pathOf([p1, p2])}" style="stroke-width:1.2"/>`);
    }

    // Bearing blocks at both ends painted on top of the rod ends
    const leftBlock = { x: W.X0 - 12, y: W.LEAD_SCREW_Y - 6, w: 8, d: 12, r: 1.5 };
    const rightBlock = { x: W.XE + 4, y: W.LEAD_SCREW_Y - 6, w: 8, d: 12, r: 1.5 };
    out.push(S(box(leftBlock, 0, 9, 3, 0.4), { tone: "mid", crease: "lo" }));
    out.push(S(box(rightBlock, 0, 9, 3, 0.4), { tone: "mid", crease: "lo" }));

    return out.join("");
  }

  function ruler() {
    const out = [];
    // Ruler bar
    out.push(
      S(box(W.RULER, 0, 2.5, 3, 0.3), {
        tone: "lo",
        crease: "faint",
      })
    );

    // Millimetric and byte offset tick marks
    for (let i = 0; i <= SLOTS; i++) {
      const x = W.X0 + i * W.PITCH;
      const isMajor = i % 8 === 0;
      const isQuarter = i % 4 === 0;
      const tickLen = isMajor ? 4 : isQuarter ? 2.8 : 1.6;
      const t1 = at([x, W.RULER.y + 0.5, 2.5]);
      const t2 = at([x, W.RULER.y + 0.5 + tickLen, 2.5]);
      out.push(
        `<path class="iso-line" data-tone="${isMajor ? 'hi' : isQuarter ? 'mid' : 'lo'}" d="${k.pathOf([t1, t2])}" style="stroke-width:${isMajor ? '0.9' : '0.6'}"/>`
      );
    }

    return out.join("");
  }

  return {
    plate,
    cassetteTray,
    gantry,
    leadScrewAndRails,
    ruler,
  };
}
