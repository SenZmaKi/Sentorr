// The whole HTTP Download Engine bench assembled in painter's order.
// Tagged with data-key for explorer legend integration.
import { k } from "./kit.mjs";
import * as W from "./layout.mjs";
import { SLOTS, DEFAULTS, derive } from "./model.mjs";
import { drawOf } from "./parts/draw.mjs";
import { benchOf } from "./parts/bench.mjs";
import { instrumentsOf } from "./parts/instruments.mjs";
import { blockSvg, partitionVanesSvg, writerCarriageSvg, dialNeedleSvg } from "./shapes.mjs";

const kit = k;
const initialDerive = derive(DEFAULTS);

export const REST = {
  fills: Array.from({ length: SLOTS }, (_, i) =>
    i < 8 ? (i < 4 ? 1.0 : 0.6) :
    i < 16 ? (i < 12 ? 1.0 : 0.45) :
    i < 24 ? (i < 20 ? 1.0 : 0.3) :
    (i < 28 ? 1.0 : 0.15)
  ),
  checkpoints: Array.from({ length: SLOTS }, (_, i) => (i % 8 < 3 ? 1 : 0)),
  partitions: initialDerive.partitions,
  writerSlot: 11.5,
  isWriting: true,
  rateMBps: 8.0,
  workers: [
    { id: 0, slot: 4, active: true },
    { id: 1, slot: 12, active: true },
    { id: 2, slot: 20, active: true },
    { id: 3, slot: 28, active: true },
  ],
};

export function sceneOf(P, state = REST, only = null) {
  const d = drawOf(P);
  const b = benchOf(d);
  const m = instrumentsOf(d);
  const items = [];

  const put = (key, svg) => {
    if (!only || only.includes(key)) {
      items.push(`<g data-key="${key}">${svg}</g>`);
    }
  };

  // 1. Heavy Base Plate
  put("base", b.plate());

  // 2. Background Instruments (Probe on left, Ledger on right rear, Gantry)
  put("probe", m.probeAnvil());
  put("ledger", m.checkpointLedger());
  put("gantry", b.gantry());

  // 3. Overhead Feed Heads (Parallel HTTP Connections)
  const headsSvg = state.workers.map((w) => {
    const x = W.cellX(w.slot);
    return `<g data-part="head" data-i="${w.id}" transform="${d.move([x, 0, 0])}">${m.feedHead(w.active)}</g>`;
  }).join("");
  put("heads", headsSvg);

  // 4. Target File Cassette & Partition Vanes
  put("cassette", b.cassetteTray());
  put("partitions", `<g data-part="partitions">${partitionVanesSvg(kit, P, state.partitions)}</g>`);

  // 5. Downloaded File Blocks (Live rising slots)
  const blocksSvg = state.fills.map((f, i) =>
    `<g data-part="block" data-i="${i}">${blockSvg(kit, P, i, f, state.checkpoints[i] === 1)}</g>`
  ).join("");
  put("blocks", blocksSvg);

  // 6. Lead Screw & Rail structure
  put("leadscrew", b.leadScrewAndRails());

  // 7. Serialized Offset Writer Carriage (_OffsetFileWriter)
  put(
    "writer",
    `<g data-part="writer">${writerCarriageSvg(kit, P, state.writerSlot, state.isWriting)}</g>`
  );

  // 8. Front Ruler & Byte scale
  put("ruler", b.ruler());

  // 9. Foreground Speed Gauge & Throttler Governor
  put(
    "governor",
    m.speedometerGauge() + `<g data-part="needle">${dialNeedleSvg(kit, P, state.rateMBps)}</g>`
  );

  return items.join("");
}
