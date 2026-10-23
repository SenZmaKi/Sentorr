// Drawing shorthands bound to one projection.
import { k } from "../kit.mjs";

let clips = 0;

export function drawOf(P) {
  const at = (point) => k.iso(point, P);
  const planeOf = (y) => k.sideMatrix([0, y], 0, P, "left");
  const flat = (x0, z0, x1, z1, r, steps = 6) => k.pathOf(k.roundedPlan({ x: x0, y: z0, w: x1 - x0, d: z1 - z0, r }, steps).map(([u, z]) => [u, -z]), true);

  /** A recess in the vertical face at [y], with its inner walls and a clipped back. */
  function recess({ x0, x1, z0, z1, r, depth }, y, back = "", backClass = "sv-well") {
    const id = `sv-clip-${clips++}`;
    const ring = k.roundedPlan({ x: x0, y: z0, w: x1 - x0, d: z1 - z0, r }, 6);
    const cx = (x0 + x1) / 2;
    const cz = (z0 + z1) / 2;
    const { sinA } = k.cameraOf(P);
    const tops = [];
    const sides = [[], [], [], []];
    ring.forEach(([ax, az], index) => {
      const [bx, bz] = ring[(index + 1) % ring.length];
      const length = Math.hypot(bx - ax, bz - az) || 1;
      let [nx, nz] = [(bz - az) / length, -(bx - ax) / length];
      if (nx * (cx - (ax + bx) / 2) + nz * (cz - (az + bz) / 2) < 0) [nx, nz] = [-nx, -nz];
      if (nx <= 0 && nz <= 0) return;
      const quad = k.pathOf([at([ax, y, az]), at([bx, y, bz]), at([bx, y - depth, bz]), at([ax, y - depth, az])], true);
      if (nz >= nx) tops.push(quad);
      else sides[Math.min(3, Math.max(0, Math.floor(((nx * -sinA + 1) / 2) * 4)))].push(quad);
    });
    const shape = flat(x0, z0, x1, z1, r);
    return [
      `<clipPath id="${id}"><path transform="${planeOf(y)}" d="${shape}"/></clipPath>`,
      `<g clip-path="url(#${id})">`,
      `<path class="iso-top" d="${tops.join("")}"/>`,
      ...sides.map((d, shade) => (d.length ? `<path class="iso-shade" data-shade="${shade}" d="${d.join("")}"/>` : "")),
      `<g transform="${planeOf(y - depth)}"><path class="${backClass}" d="${shape}"/>${back}<path class="iso-line" data-tone="faint" d="${shape}"/></g>`,
      `</g>`,
      `<g transform="${planeOf(y)}"><path class="iso-line" data-tone="lo" d="${shape}"/></g>`,
    ].join("");
  }

  return {
    P,
    at,
    planeOf,
    flat,
    recess,
    S: (paths, style) => k.solidSvg(paths, style),
    L: (d, style) => k.lineSvg(d, style),
    D: (points, style) => k.dotsSvg(points, style),
    box: (plan, z, h, steps = 3, bevel = 0.4) => k.slabOf(plan, z, h, P, steps, bevel),
    byDepth: (points) => [...points].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P)),
    halo: (plan, z, blur = 4) => `<path class="iso-halo" d="${k.haloOf(plan, z, 0.1, P)}" style="filter:blur(${blur}px)"/>`,
    move: (by) => k.translateAlong(P, by),
  };
}
