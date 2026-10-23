// Drawing shorthands bound to one projection.
import { k } from "../kit.mjs";

let clips = 0;

export function drawOf(P) {
  const at = (point) => k.iso(point, P);
  const planeOf = (y) => k.sideMatrix([0, y], 0, P, "left");
  const flat = (x0, z0, x1, z1, r, steps = 6) =>
    k.pathOf(
      k.roundedPlan({ x: x0, y: z0, w: x1 - x0, d: z1 - z0, r }, steps).map(([u, z]) => [u, -z]),
      true
    );

  return {
    P,
    at,
    planeOf,
    flat,
    S: (paths, style) => k.solidSvg(paths, style),
    L: (d, style) => k.lineSvg(d, style),
    D: (points, style) => k.dotsSvg(points, style),
    box: (plan, z, h, steps = 3, bevel = 0.4) => k.slabOf(plan, z, h, P, steps, bevel),
    byDepth: (points) =>
      [...points].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P)),
    halo: (plan, z, blur = 4) =>
      `<path class="iso-halo" d="${k.haloOf(plan, z, 0.1, P)}" style="filter:blur(${blur}px)"/>`,
    move: (by) => k.translateAlong(P, by),
  };
}
