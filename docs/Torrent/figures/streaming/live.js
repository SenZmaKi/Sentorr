// The page's script. The build prepends the kit, the explorer runtime,
// model.mjs, layout.mjs and shapes.mjs (exports stripped), `P` and `PRESETS`.
const kit = { slabOf, solidSvg, lineOnTop, lineSvg, dotsSvg, iso };
const stage = document.querySelector(".iso-stage");
const svg = stage.querySelector("svg");
const q = (sel) => svg.querySelector(sel);
const all = (sel, root = svg) => [...root.querySelectorAll(sel)];
const blocks = all('[data-part="block"]');
const headEls = all('[data-part="head"]');
const filaments = all('[data-part="filament"]');
const lamps = all('[data-part="lamp"]');
const carriage = q('[data-part="carriage"]'), comb = q('[data-part="comb"]'), lid = q('[data-part="lid"]');
const playheadEl = q('[data-part="playhead"]'), strip = q('[data-part="strip"]');
const picture = q('[data-part="picture"]'), sun = q('[data-part="sun"]'), spinner = q('[data-part="spinner"]');
const cached = q('[data-part="cached"]'), played = q('[data-part="played"]'), screenHead = q('[data-part="screen-head"]');
const dots = all("circle", spinner);
const readout = document.querySelector("[data-readout]");
const still = matchMedia("(prefers-reduced-motion: reduce)");
const BAR_FROM = CRT.x0 + 3, BAR_TO = CRT.x1 - 3, BAR_Z = CRT.z0 + 2.6;

let s = create(DEFAULTS);
seek(s, 0);
let drawn = [], teeth = [], speed = 1, clock = 0, next = 0, touring = !still.matches;
let frame = 0, last = 0, visible = false, spin = 0, statsAt = 0;

// The tour walks every stage: start cold, seek ahead into missing pieces,
// seek back into verified ones, pause while peers keep downloading, close.
const TOUR = [
  [20, () => seek(s, 0.72 * s.c.LENGTH_S)],
  [31, () => seek(s, 0.22 * s.c.LENGTH_S)],
  [39, () => (s.paused = true)],
  [44, () => (s.paused = false)],
  [56, () => reset(s)],
];
const LOOP = 57;

const fmt = Explorer.fmtDuration;
const secs = (t) => (t < 10 ? t.toFixed(2) : t.toFixed(1)) + " s";
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;

function rebuild() {
  drawn = new Array(SOCKETS).fill(-1);
  comb.innerHTML = combSvg(kit, P, s.c.URGENT);
  teeth = all('[data-part="tooth"]', comb);
  lid.innerHTML = lidSvg(kit, P, s.c.N);
}

function phase() {
  if (s.clearing > 0) return ["closing", "idle"];
  if (s.phase === "ended") return ["ended", "idle"];
  if (s.phase === "buffering") return ["buffering", "wait"];
  if (s.phase === "starting") return ["starting", "wait"];
  return s.paused ? ["paused", "idle"] : ["playing", "ok"];
}

/** Which of the algorithm's stages the model is in. */
function stageOf() {
  if (s.phase === "buffering") return "stall";
  if (s.phase === "starting" || s.clearing > 0) return "urgent";
  if (s.starting) return "hold";
  const w = windowsOf(s);
  for (let i = 0; i < s.c.N; i++) if (w.priority[i] > 0 && s.have[i] < 1) return "ahead";
  return "steady";
}

function report() {
  const c = s.c;
  const cache = cacheOf(s);
  const verified = s.have.filter((h) => h >= 1).length;
  const busy = s.heads.filter((h, i) => i < c.peers && h.busy).length;
  ex.setStats({
    position: `${fmt(s.pos)} / ${fmt(c.LENGTH_S)}`,
    cache: `${cache.toFixed(1)} s`,
    speed: `${(speedOf(s) / 1e6).toFixed(1)} MB/s`,
    busy: `${busy} of ${c.peers}`,
    verified: `${verified} / ${c.N}`,
    urgent: `${plural(c.URGENT, "piece")} · ${secs(c.URGENT * c.PIECE_S)}`,
    step: secs(c.STEP_MS / 1000),
    ratio: `${(c.swarmMBps / (c.RATE / 1e6)).toFixed(1)}×`,
    piece: `${c.pieceMiB} MiB, ${secs(c.PIECE_S)} each`,
    ahead: c.aheadMin > 0 ? `${c.aheadMin} min` : "the entire file",
  });
  const [word, tone] = phase();
  ex.setPhase(word, tone);
  ex.setStage(stageOf());
  ex.setPlaying(!s.paused);
  ex.setTouring(touring);
}

function draw(dt) {
  for (let i = 0; i < SOCKETS; i++) {
    const have = i < s.c.N ? s.have[i] : 0;
    const f = have >= 1 ? 1 : Math.round(have * 40) / 40;
    if (f !== drawn[i]) { drawn[i] = f; blocks[i].innerHTML = blockSvg(kit, P, i, f); }
  }
  s.heads.forEach((h, i) => {
    const live = i < s.c.peers;
    headEls[i].setAttribute("display", live ? "inline" : "none");
    headEls[i].setAttribute("transform", translateAlong(P, [cellX(h.x), 0, 0]));
    lamps[i].toggleAttribute("data-on", live && h.busy);
    lamps[i].toggleAttribute("data-off", !live);
    const on = live && h.busy && drawn[h.piece] > 0 && drawn[h.piece] < 1;
    filaments[i].setAttribute("display", on ? "inline" : "none");
    if (on) {
      const [x, y] = iso([cellX(h.x), NOZZLE_Y, TRAY_TOP + Math.max(0.3, drawn[h.piece] * BLOCK_H)], P);
      filaments[i].querySelector("path").setAttribute("d", pathOf([iso([cellX(h.x), NOZZLE_Y, TIP_Z], P), [x, y]]));
      const dot = filaments[i].querySelector("circle");
      dot.setAttribute("cx", x.toFixed(2));
      dot.setAttribute("cy", y.toFixed(2));
    }
  });
  const reader = readerOf(s);
  carriage.setAttribute("transform", translateAlong(P, [cellX(reader), 0, 0]));
  teeth.forEach((el, i) => el.setAttribute("display", reader + i < s.c.N ? "inline" : "none"));
  playheadEl.setAttribute("transform", translateAlong(P, [X0 + (s.pos / s.c.PIECE_S) * PITCH, 0, 0]));
  const cache = cacheOf(s);
  const stripKey = `${s.pos.toFixed(2)}:${cache.toFixed(2)}:${s.c.PIECE_S}`;
  if (strip.dataset.at !== stripKey) { strip.dataset.at = stripKey; strip.innerHTML = stripSvg(kit, P, s.pos, cache, s.c.PIECE_S); }
  const share = (t) => (BAR_FROM + (t / s.c.LENGTH_S) * (BAR_TO - BAR_FROM)).toFixed(2);
  played.setAttribute("d", `M${BAR_FROM} ${-BAR_Z}H${share(s.pos)}`);
  cached.setAttribute("d", `M${share(s.pos)} ${-BAR_Z}H${share(s.pos + cache)}`);
  screenHead.setAttribute("cx", share(s.pos));
  sun.setAttribute("cx", (CRT.x0 + 6 + (s.pos / s.c.LENGTH_S) * (CRT.x1 - CRT.x0 - 12)).toFixed(2));
  const waiting = (s.phase === "starting" || s.phase === "buffering") && s.clearing <= 0;
  spin += dt;
  picture.style.opacity = waiting ? "0.35" : s.paused ? "0.7" : "1";
  spinner.style.opacity = waiting ? "1" : "0";
  dots.forEach((d, i) => (d.style.opacity = String(0.35 + 0.65 * Math.max(0, Math.sin(spin * 4 - i * 0.9)))));
  const text = `${phase()[0]} · ${fmt(s.pos)} · cache ${cache.toFixed(1)} s · ${(speedOf(s) / 1e6).toFixed(1)} MB/s`;
  if (readout.textContent !== text) readout.textContent = text;
}

function advance(dt) {
  if (touring) {
    clock += dt;
    while (next < TOUR.length && clock >= TOUR[next][0]) TOUR[next++][1]();
    if (clock >= LOOP) { clock = 0; next = 0; }
  }
  step(s, dt);
}

function tick(now) {
  const dt = last ? Math.min((now - last) / 1000, 1 / 30) : 1 / 60;
  last = now;
  // Faster simulation runs in steps no longer than a frame.
  const n = Math.ceil(speed);
  for (let i = 0; i < n; i++) advance((dt * speed) / n);
  draw(dt);
  if (now - statsAt > 120) { statsAt = now; report(); }
  frame = visible ? requestAnimationFrame(tick) : 0;
}
const run = () => { if (!frame && visible && !still.matches) { last = 0; frame = requestAnimationFrame(tick); } };
// Reduced motion: no tour; each change jumps the bench 12 s of film ahead.
function settle() {
  for (let i = 0; i < 12 * 30; i++) advance(1 / 30);
  s.heads.forEach((h, i) => (h.x = h.piece >= 0 ? h.piece : parkOf(i)));
  draw(0);
  report();
}
function describe() {
  stage.setAttribute("aria-valuemax", String(s.c.N - 1));
  stage.setAttribute("aria-valuenow", String(pieceAt(s, s.pos)));
  stage.setAttribute("aria-valuetext", `${phase()[0]} at piece ${pieceAt(s, s.pos) + 1} of ${s.c.N}, ${cacheOf(s).toFixed(0)} seconds cached`);
}
/** Every reader action stops the tour; the Tour button brings it back. */
function steer(action) {
  touring = false;
  action();
  describe();
  if (still.matches) settle();
  else report();
  run();
}
new IntersectionObserver((entries) => { visible = entries[entries.length - 1].isIntersecting; if (visible) run(); }, { rootMargin: "120px 0px" }).observe(stage);

const centres = Array.from({ length: SOCKETS }, (_, i) => iso([cellX(i), 0, TRAY_TOP], P));
function pieceUnder(event) {
  const m = svg.getScreenCTM();
  if (!m) return null;
  const p = new DOMPoint(event.clientX, event.clientY).matrixTransform(m.inverse());
  let best = 0, gap = Infinity;
  centres.forEach(([x, y], i) => { const d = Math.hypot(x - p.x, (y - p.y) * 0.6); if (d < gap) { gap = d; best = i; } });
  return gap < 60 ? Math.min(best, s.c.N - 1) : null;
}
const jump = () => Math.max(10, s.c.PIECE_S);
stage.addEventListener("click", (event) => { const i = pieceUnder(event); if (i !== null) steer(() => seek(s, i * s.c.PIECE_S)); });
stage.addEventListener("keydown", (event) => {
  const keys = {
    ArrowRight: () => seek(s, s.pos + jump()), ArrowUp: () => seek(s, s.pos + jump()),
    ArrowLeft: () => seek(s, s.pos - jump()), ArrowDown: () => seek(s, s.pos - jump()),
    Home: () => seek(s, 0), End: () => seek(s, s.c.LENGTH_S - jump()),
    " ": () => (s.paused = !s.paused), Enter: () => (s.paused = !s.paused),
    Escape: () => reset(s),
  };
  if (!keys[event.key]) return;
  event.preventDefault();
  steer(keys[event.key]);
});

// The explorer. Network and the setting apply live; a new film starts over.
const LIVE = new Set(["swarmMBps", "peers", "aheadMin"]);
// A preset's length is applied after the slider's range widens to fit it.
let pendingLength = null;
const ex = Explorer.mount(document.querySelector("[data-explorer]"), {
  presets: PRESETS,
  onChange(changed, values) {
    const film = Object.keys(changed).some((name) => !LIVE.has(name));
    if ("mbps" in changed || "pieceMiB" in changed || pendingLength !== null) fitLength(values);
    steer(() => {
      if (film) { s = create(values); seek(s, 0); rebuild(); }
      else retune(s, values);
    });
  },
  onAction(act, value) {
    if (act === "speed") { speed = value; return; }
    if (act === "preset") { pendingLength = PRESETS[value]?.lengthS ?? DEFAULTS.lengthS; return; }
    if (act === "defaults") { pendingLength = DEFAULTS.lengthS; return; }
    if (act === "tour") {
      touring = !touring;
      clock = 0; next = 0;
      if (touring) reset(s);
      report();
      return run();
    }
    const acts = {
      play: () => (s.paused = !s.paused),
      restart: () => reset(s),
      back: () => seek(s, s.pos - jump()),
      ahead: () => seek(s, s.pos + jump()),
      middle: () => seek(s, s.c.LENGTH_S / 2),
      close: () => reset(s),
    };
    if (acts[act]) steer(acts[act]);
  },
});
/** The length slider's range follows what the tray holds at this bitrate and piece size. */
function fitLength(values) {
  const c = derive(values);
  const wanted = pendingLength ?? values.lengthS;
  ex.setRange("lengthS", { min: c.PIECE_S, max: c.maxLength, step: "any" });
  ex.set("lengthS", Math.min(wanted, c.maxLength));
  pendingLength = null;
}
Explorer.legend(document.querySelector(".ex-legend ul"), stage);

fitLength(ex.values);
rebuild();
if (still.matches) { touring = false; settle(); seek(s, 0.72 * s.c.LENGTH_S); settle(); }
draw(0);
report();
describe();
