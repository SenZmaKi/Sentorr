// Where everything sits. World units: x along the file, y toward the front,
// z up, about 1 px each.
import { SOCKETS, MAX_PEERS } from "./model.mjs";

export const PITCH = 8;
export const X0 = -150; // left edge of socket 0
export const XE = X0 + SOCKETS * PITCH;
export const cellX = (i) => X0 + (i + 0.5) * PITCH;

export const PLATE = { x: -252, y: -58, w: 462, d: 120, r: 8 };
export const PLATE_H = 12;
export const FOOT_H = 5;

export const TRAY = { x: X0 - 6, y: -14, w: SOCKETS * PITCH + 12, d: 28, r: 2 };
export const TRAY_Z = 2;
export const TRAY_TOP = 10;
export const BLOCK_H = 7;

export const BEAM = { x: X0 - 22, y: -43, w: XE + 60 - (X0 - 22), d: 10, r: 1.2 };
export const BEAM_Z = 40;
export const BEAM_TOP = 46;
export const POSTS = [X0 - 22, XE + 52];
export const NOZZLE_Y = -3;
export const TIP_Z = 21.5;

export const BAR = { y: 16.5, d: 1.6, z: 5, h: 2 };
export const RAILS = [22, 30];
export const RAIL_H = 2.5;
export const COMB_Y = 14.4;
export const MAX_TEETH = 16; // the engine caps the urgent window at 16 pieces

export const RULER = { x: X0 - 4, y: 40, w: SOCKETS * PITCH + 8, d: 6, r: 1 };
// The cache strip's lane on the ruler, in front of the ticks.
export const LANE = { y: RULER.y + 3.9, d: 1.7 };

export const MON = { x: -238, y: -22, w: 46, d: 40, r: 3 };
export const MON_Z = 4;
export const MON_TOP = 40;
export const FRONT = MON.y + MON.d;
export const SIDE = MON.x + MON.w;
export const CRT = { x0: -232, x1: -198, z0: 15, z1: 35, r: 3, depth: 2.4 };

export const LINK = { x: 150, y: 8, w: 44, d: 18, r: 2 };
export const LINK_TOP = 11;
export const lampX = (i) => LINK.x + 9 + i * 5.2;
export const LAMPS = MAX_PEERS;
