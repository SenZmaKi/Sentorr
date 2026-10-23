// Spatial layout for the HTTP Download Engine figure.
// World units: x along file byte offset, y toward front, z vertical (mm/px).
import { SLOTS } from "./model.mjs";

export const PITCH = 8.5; // distance between slot centres
export const X0 = -136;   // left edge of slot 0
export const XE = X0 + SLOTS * PITCH; // right edge of slot 31
export const cellX = (i) => X0 + (i + 0.5) * PITCH;

// Base plate
export const PLATE = { x: -248, y: -58, w: 466, d: 118, r: 8 };
export const PLATE_H = 12;
export const FOOT_H = 5;

// Cassette / Target File Bed
export const TRAY = { x: X0 - 6, y: -16, w: SLOTS * PITCH + 12, d: 28, r: 2 };
export const TRAY_Z = 2;
export const TRAY_TOP = 10;
export const BLOCK_H = 7.5;

// Overhead Gantry & Feed Heads (HTTP Parallel Connections)
export const GANTRY_Y = -34;
export const GANTRY_BEAM = { x: X0 - 18, y: GANTRY_Y - 4, w: XE - X0 + 36, d: 8, r: 1.5 };
export const GANTRY_Z = 38;
export const GANTRY_TOP = 44;
export const POSTS = [X0 - 16, XE + 14];
export const NOZZLE_Y = -2;
export const TIP_Z = 20;

// Lead Screw & Indexing Writer Carriage (_OffsetFileWriter)
export const LEAD_SCREW_Y = 18;
export const LEAD_SCREW_Z = 6;
export const RAILS = [14, 22];
export const CARRIAGE_W = 10;
export const CARRIAGE_D = 12;

// Front Ruler (File Byte Offset & Partition markers)
export const RULER = { x: X0 - 4, y: 38, w: SLOTS * PITCH + 8, d: 6, r: 1 };

// Left End: HTTP Range Probe & ETag Caliper (Probe Anvil)
export const PROBE_BOX = { x: -236, y: -24, w: 42, d: 42, r: 3 };
export const PROBE_Z = 2;
export const PROBE_TOP = 32;

// Right End: Checkpoint Ledger & SHA-256 Notary Reel
export const LEDGER_BOX = { x: 154, y: -38, w: 52, d: 38, r: 3 };
export const LEDGER_Z = 2;
export const LEDGER_TOP = 28;

// Right Front: Throttler Governor & Speed Gauge
export const GAUGE_BOX = { x: 154, y: 8, w: 48, d: 36, r: 3 };
export const GAUGE_Z = 2;
export const GAUGE_TOP = 36;
export const DIAL = { cx: 178, cy: 26, r: 13, z: 22 };
