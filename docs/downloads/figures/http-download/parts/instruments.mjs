// The instruments and mechanisms of the HTTP Download Engine.
import { k } from "../kit.mjs";
import * as W from "../layout.mjs";

export function instrumentsOf(d) {
  const { P, S, L, D, box, at } = d;

  /** A single overhead HTTP range worker feed head */
  function feedHead(active = false) {
    const out = [];
    // Carriage mount clamp
    const clampPlan = { x: -4, y: W.GANTRY_Y - 4.5, w: 8, d: 9, r: 1 };
    out.push(
      S(box(clampPlan, W.GANTRY_Z - 2, 8, 3, 0.3), {
        tone: "mid",
        crease: "lo",
      })
    );

    // Solenoid valve body
    const solenoidPlan = { x: -3, y: W.NOZZLE_Y - 3, w: 6, d: 6, r: 1.2 };
    out.push(
      S(box(solenoidPlan, W.TIP_Z + 6, 12, 3, 0.4), {
        tone: "mid",
        crease: "hi",
      })
    );

    // Nozzle tip extending down
    const tipPlan = { x: -1.2, y: W.NOZZLE_Y - 1.2, w: 2.4, d: 2.4, r: 0.5 };
    out.push(
      S(box(tipPlan, W.TIP_Z, 6, 2, 0.2), {
        tone: "hi",
        crease: "lo",
      })
    );

    // Activity lamp on the solenoid face
    const lampCenter = at([0, W.NOZZLE_Y + 3.2, W.TIP_Z + 12]);
    out.push(
      `<circle class="iso-dot" cx="${lampCenter[0].toFixed(2)}" cy="${lampCenter[1].toFixed(2)}" r="1.3" data-tone="${active ? 'hi' : 'lo'}" style="${active ? 'fill:var(--iso-hi);' : ''}"/>`
    );

    // Intake pipe connection entering from top
    const pipeTop = at([0, W.NOZZLE_Y, W.TIP_Z + 20]);
    const pipeBottom = at([0, W.NOZZLE_Y, W.TIP_Z + 18]);
    out.push(
      `<path class="iso-line" data-tone="mid" d="${k.pathOf([pipeTop, pipeBottom])}" style="stroke-width:2"/>`
    );

    return out.join("");
  }

  /** The HTTP Range Probe & ETag Caliper assembly at the left end */
  function probeAnvil() {
    const out = [];
    // Housing block
    out.push(
      S(box(W.PROBE_BOX, 0, W.PROBE_TOP, 4, 1.2), {
        tone: "lo",
        crease: "mid",
      })
    );

    // Micrometer barrel
    const barrelPlan = { x: W.PROBE_BOX.x + 8, y: W.PROBE_BOX.y + 12, w: 26, d: 18, r: 2 };
    out.push(
      S(box(barrelPlan, W.PROBE_TOP, 6, 3, 0.4), {
        tone: "mid",
        crease: "lo",
      })
    );

    // Vernier scale ticks on the barrel top
    for (let i = 0; i < 5; i++) {
      const vx = barrelPlan.x + 4 + i * 4.5;
      const v1 = at([vx, barrelPlan.y + 3, W.PROBE_TOP + 6]);
      const v2 = at([vx, barrelPlan.y + 7, W.PROBE_TOP + 6]);
      out.push(`<path class="iso-line" data-tone="mid" d="${k.pathOf([v1, v2])}" style="stroke-width:0.7"/>`);
    }

    // Knurled thumb thimble knob
    const knobPlan = { x: W.PROBE_BOX.x + 2, y: W.PROBE_BOX.y + 15, w: 6, d: 12, r: 1.5 };
    out.push(
      S(box(knobPlan, W.PROBE_TOP + 0.5, 5, 3, 0.3), {
        tone: "hi",
        crease: "lo",
      })
    );

    // Probe contact caliper jaw touching the first slot
    const jawPlan = { x: W.PROBE_BOX.x + W.PROBE_BOX.w, y: -8, w: 8, d: 16, r: 1 };
    out.push(
      S(box(jawPlan, W.TRAY_TOP, 8, 2, 0.3), {
        tone: "hi",
        crease: "mid",
      })
    );

    // Status label plate
    const platePlan = { x: W.PROBE_BOX.x + 6, y: W.PROBE_BOX.y + W.PROBE_BOX.d - 6, w: 30, d: 4, r: 0.5 };
    out.push(
      S(box(platePlan, W.PROBE_TOP - 12, 8, 2, 0.2), {
        tone: "mid",
        crease: "faint",
      })
    );

    return out.join("");
  }

  /** The Checkpoint Ledger & SHA-256 Notary Reel at the right rear */
  function checkpointLedger() {
    const out = [];
    // Ledger base console
    out.push(
      S(box(W.LEDGER_BOX, 0, W.LEDGER_TOP, 4, 1.2), {
        tone: "lo",
        crease: "mid",
      })
    );

    // Tape supply spool
    const spool1 = { x: W.LEDGER_BOX.x + 8, y: W.LEDGER_BOX.y + 8, w: 14, d: 14, r: 7 };
    out.push(
      S(box(spool1, W.LEDGER_TOP, 5, 8, 0.5), {
        tone: "mid",
        crease: "lo",
      })
    );

    // Tape take-up spool with ratchet gear
    const spool2 = { x: W.LEDGER_BOX.x + 28, y: W.LEDGER_BOX.y + 8, w: 16, d: 16, r: 8 };
    out.push(
      S(box(spool2, W.LEDGER_TOP, 6, 8, 0.6), {
        tone: "hi",
        crease: "mid",
      })
    );

    // Paper tape strip spanning between spools
    const tape1 = at([spool1.x + 10, spool1.y + 7, W.LEDGER_TOP + 3]);
    const tape2 = at([spool2.x + 4, spool2.y + 7, W.LEDGER_TOP + 3]);
    out.push(
      `<path class="iso-line" data-tone="hi" d="${k.pathOf([tape1, tape2])}" style="stroke-width:2.4"/>`
    );

    // Hash notary stamp head on a vertical column
    const stampArm = { x: W.LEDGER_BOX.x + 18, y: W.LEDGER_BOX.y + 22, w: 16, d: 10, r: 1.5 };
    out.push(
      S(box(stampArm, W.LEDGER_TOP, 10, 3, 0.4), {
        tone: "mid",
        crease: "hi",
      })
    );

    // Stamping plunger knob
    const stampKnob = { x: W.LEDGER_BOX.x + 23, y: W.LEDGER_BOX.y + 24, w: 6, d: 6, r: 3 };
    out.push(
      S(box(stampKnob, W.LEDGER_TOP + 10, 4, 6, 0.3), {
        tone: "hi",
        crease: "lo",
      })
    );

    return out.join("");
  }

  /** Dial Speedometer & Throttler Governor console */
  function speedometerGauge() {
    const out = [];
    // Console housing
    out.push(
      S(box(W.GAUGE_BOX, 0, W.GAUGE_TOP, 4, 1.2), {
        tone: "lo",
        crease: "mid",
      })
    );

    // Circular instrument dial bezel
    const bezelPlan = {
      x: W.DIAL.cx - W.DIAL.r - 2,
      y: W.DIAL.cy - W.DIAL.r - 2,
      w: (W.DIAL.r + 2) * 2,
      d: (W.DIAL.r + 2) * 2,
      r: W.DIAL.r + 2,
    };
    out.push(
      S(box(bezelPlan, W.DIAL.z - 2, 4, 8, 0.6), {
        tone: "mid",
        crease: "hi",
      })
    );

    // Dial face recessed inlay
    const dialFace = {
      x: W.DIAL.cx - W.DIAL.r,
      y: W.DIAL.cy - W.DIAL.r,
      w: W.DIAL.r * 2,
      d: W.DIAL.r * 2,
      r: W.DIAL.r,
    };
    out.push(
      S(box(dialFace, W.DIAL.z, 0.6, 8, 0.2), {
        tone: "lo",
        crease: "faint",
      })
    );

    // Calibration speed scale ticks around arc
    for (let i = 0; i <= 8; i++) {
      const angle = -140 + (i / 8) * 100;
      const rad = (angle * Math.PI) / 180;
      const r1 = W.DIAL.r - 2.8;
      const r2 = W.DIAL.r - 1.2;
      const p1 = at([W.DIAL.cx + Math.cos(rad) * r1, W.DIAL.cy + Math.sin(rad) * r1, W.DIAL.z + 0.6]);
      const p2 = at([W.DIAL.cx + Math.cos(rad) * r2, W.DIAL.cy + Math.sin(rad) * r2, W.DIAL.z + 0.6]);
      out.push(
        `<path class="iso-line" data-tone="${i % 2 === 0 ? 'mid' : 'faint'}" d="${k.pathOf([p1, p2])}" style="stroke-width:0.8"/>`
      );
    }

    return out.join("");
  }

  return {
    feedHead,
    probeAnvil,
    checkpointLedger,
    speedometerGauge,
  };
}
