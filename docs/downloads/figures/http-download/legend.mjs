// The parts legend: each entry is a thumbnail cut from the actual figure
// in its own camera, explaining what the part stands for.
import { k } from "./kit.mjs";
import * as W from "./layout.mjs";
import { REST, sceneOf } from "./scene.mjs";
import { CAMERA } from "./camera.mjs";
import { thumbSvg, partsHtml as listHtml } from "./kit.mjs";

const span = (x0, x1, y0, y1, z0, z1) =>
  k.boxCorners({ x: x0, y: y0, w: x1 - x0, d: y1 - y0, r: 0 }, z0, z1);
const stat = (id) => `<span data-stat="${id}"></span>`;

export const ENTRIES = [
  {
    key: "writer",
    name: "Serialized Offset Writer",
    text: `The single RandomAccessFile handle (_OffsetFileWriter). Multiple HTTP range streams funnel into its asynchronous FIFO queue, indexing to the target byte offset before writing chunks.`,
    view: span(W.X0 + 4 * W.PITCH, W.X0 + 16 * W.PITCH, 4, 32, 0, 16),
    draw: ["cassette", "blocks", "leadscrew", "writer"],
  },
  {
    key: "heads",
    name: "Intake Feed Heads",
    text: `Parallel HTTP connections (${stat("workers")}). Each streams a distinct byte-range segment (Range: bytes=start-end) concurrently, lighting its activity lamp while receiving data.`,
    view: span(W.X0 + 2 * W.PITCH, W.X0 + 12 * W.PITCH, W.GANTRY_Y - 8, W.NOZZLE_Y + 8, W.TIP_Z - 2, W.GANTRY_TOP + 4),
    draw: ["gantry", "heads", "cassette"],
  },
  {
    key: "partitions",
    name: "Partition Vanes",
    text: `Byte-range division boundaries. The engine splits the file into ${stat("partitions")} equal contiguous spans (plus remainder bytes) computed by computePartRanges.`,
    view: span(W.X0 + 6 * W.PITCH, W.X0 + 18 * W.PITCH, W.TRAY.y - 4, W.TRAY.y + W.TRAY.d + 4, 0, W.BLOCK_H + 6),
    draw: ["cassette", "partitions", "blocks"],
  },
  {
    key: "blocks",
    name: "File Block Cassette",
    text: `The sparse target file. As bytes arrive, 2 MiB blocks rise in their assigned slots. Blocks with verified SHA-256 hashes glow brightly as immutable persistent chunks.`,
    view: span(W.X0 + 2 * W.PITCH, W.X0 + 14 * W.PITCH, W.TRAY.y - 2, W.TRAY.y + W.TRAY.d + 2, 0, W.BLOCK_H + 5),
    draw: ["cassette", "blocks"],
  },
  {
    key: "probe",
    name: "Range Probe Caliper",
    text: `Initial probe (Range: bytes=0-1). Validates whether the server supports 206 Partial Content, verifies Content-Length, and locks the ETag validator. If 200 OK is returned, single-stream fallback is chosen.`,
    view: span(W.PROBE_BOX.x - 4, W.PROBE_BOX.x + W.PROBE_BOX.w + 12, W.PROBE_BOX.y - 4, W.PROBE_BOX.y + W.PROBE_BOX.d + 4, 0, W.PROBE_TOP + 8),
    draw: ["base", "probe", "cassette"],
  },
  {
    key: "ledger",
    name: "Checkpoint Notary Spool",
    text: `The persistent HttpCheckpoint journal. Every 1 MiB chunk written is SHA-256 hashed and recorded to the .checkpoint ledger, ensuring crash resilience and safe resumption without duplicate downloads.`,
    view: span(W.LEDGER_BOX.x - 4, W.LEDGER_BOX.x + W.LEDGER_BOX.w + 4, W.LEDGER_BOX.y - 4, W.LEDGER_BOX.y + W.LEDGER_BOX.d + 4, 0, W.LEDGER_TOP + 16),
    draw: ["base", "ledger"],
  },
  {
    key: "governor",
    name: "Speedometer & Throttler",
    text: `DownloadThrottler token bucket & rate tachometer. Enforces bandwidth limits (${stat("speed")}) across all concurrent streams and displays instantaneous throughput (${stat("rate")}).`,
    view: span(W.GAUGE_BOX.x - 4, W.GAUGE_BOX.x + W.GAUGE_BOX.w + 4, W.GAUGE_BOX.y - 4, W.GAUGE_BOX.y + W.GAUGE_BOX.d + 4, 0, W.GAUGE_TOP + 8),
    draw: ["base", "governor"],
  },
  {
    key: "ruler",
    name: "Calibrated Byte Scale",
    text: `Linear byte-offset coordinate ruler. Maps file offsets from 0 B to ${stat("filesize")}, with ticks marking 1 MiB block boundaries.`,
    view: span(W.X0 - 2, W.X0 + 12 * W.PITCH, W.RULER.y - 2, W.RULER.y + W.RULER.d + 2, 0, 6),
    draw: ["base", "ruler"],
  },
];

export const KEYS = ENTRIES.map((e) => e.key);

export function legendHtml() {
  return listHtml(
    ENTRIES.map((entry) => {
      const state = { ...REST, ...(entry.state ?? {}) };
      return {
        ...entry,
        thumb: thumbSvg({
          view: entry.view,
          camera: CAMERA,
          body: (P) => sceneOf(P, state, entry.draw),
        }),
      };
    })
  );
}
