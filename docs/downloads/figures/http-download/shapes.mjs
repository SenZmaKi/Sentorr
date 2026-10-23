// Shapes that change dynamically during simulation.
// Bound to kit primitives and projection P.
import { PITCH, X0, TRAY, TRAY_TOP, BLOCK_H, LEAD_SCREW_Y, LEAD_SCREW_Z, CARRIAGE_W, CARRIAGE_D, DIAL } from "./layout.mjs";
import { SLOTS } from "./model.mjs";

const blockPlan = (i) => ({
  x: X0 + i * PITCH + 1.2,
  y: -11,
  w: PITCH - 2.4,
  d: 18,
  r: 0.6,
});

/** An individual file block rising in its socket */
export function blockSvg(kit, P, i, fill, checkpointed = false) {
  if (fill <= 0.001) return "";
  const done = fill >= 0.999;
  const paths = kit.slabOf(
    blockPlan(i),
    TRAY_TOP,
    Math.max(0.4, fill * BLOCK_H),
    P,
    2,
    done ? 0.35 : 0
  );
  return kit.solidSvg(paths, {
    tone: done ? (checkpointed ? "hi" : "mid") : "lo",
    crease: done ? "lo" : "faint",
  });
}

/** Partition divider vanes separating worker byte ranges */
export function partitionVanesSvg(kit, P, partitions) {
  const out = [];
  for (let p of partitions) {
    if (p.startSlot > 0) {
      const x = X0 + p.startSlot * PITCH;
      const vanePlan = { x: x - 0.7, y: TRAY.y + 1, w: 1.4, d: TRAY.d - 2, r: 0.3 };
      out.push(
        kit.solidSvg(kit.slabOf(vanePlan, TRAY_TOP, BLOCK_H + 2.5, P, 2, 0.2), {
          tone: "hi",
          crease: "mid",
        })
      );
    }
  }
  return out.join("");
}

/** The Serialized Offset Writer Carriage (_OffsetFileWriter) */
export function writerCarriageSvg(kit, P, slotPos, isWriting) {
  const x = X0 + (slotPos + 0.5) * PITCH;
  const plan = {
    x: x - CARRIAGE_W / 2,
    y: LEAD_SCREW_Y - CARRIAGE_D / 2,
    w: CARRIAGE_W,
    d: CARRIAGE_D,
    r: 1.2,
  };
  const body = kit.slabOf(plan, LEAD_SCREW_Z - 1.5, 5, P, 2, 0.4);

  // Actuator pin pointing toward tray
  const pinTip = kit.iso([x, -1, TRAY_TOP + (isWriting ? 2 : 4)], P);
  const pinBase = kit.iso([x, LEAD_SCREW_Y - CARRIAGE_D / 2, LEAD_SCREW_Z + 1], P);

  return [
    kit.solidSvg(body, { tone: "mid", crease: "hi" }),
    // Stylus needle
    `<path class="iso-line" data-tone="${isWriting ? 'hi' : 'mid'}" d="${kit.pathOf([pinBase, pinTip])}" style="stroke-width:1.2"/>`,
    `<g class="iso-dots" data-tone="${isWriting ? 'hi' : 'mid'}"><circle r="0.8" cx="${pinTip[0].toFixed(2)}" cy="${pinTip[1].toFixed(2)}"/></g>`,
  ].join("");
}

/** Dial needle indicating current download throughput */
export function dialNeedleSvg(kit, P, rateMBps, maxRate = 16) {
  const angle = -140 + (Math.min(rateMBps, maxRate) / maxRate) * 100; // degrees
  const rad = (angle * Math.PI) / 180;
  const r = 9;
  const nx = DIAL.cx + Math.cos(rad) * r;
  const ny = DIAL.cy + Math.sin(rad) * r;

  const c = kit.iso([DIAL.cx, DIAL.cy, DIAL.z], P);
  const tip = kit.iso([nx, ny, DIAL.z], P);

  return [
    `<path class="iso-line" data-tone="hi" d="${kit.pathOf([c, tip])}" style="stroke-width:1.1"/>`,
    `<circle class="iso-dot" cx="${c[0].toFixed(2)}" cy="${c[1].toFixed(2)}" r="1.4" data-tone="mid"/>`,
    `<circle class="iso-dot" cx="${tip[0].toFixed(2)}" cy="${tip[1].toFixed(2)}" r="0.75" data-tone="hi"/>`,
  ].join("");
}
