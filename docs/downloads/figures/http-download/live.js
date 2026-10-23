// Client-side live controller for the HTTP Download Engine figure.
const kit = { slabOf, solidSvg, lineOnTop, lineSvg, dotsSvg, iso, pathOf, translateAlong };
const stage = document.querySelector(".iso-stage");
const svg = stage.querySelector("svg");
const q = (sel) => svg.querySelector(sel);
const all = (sel, root = svg) => [...root.querySelectorAll(sel)];

const blocks = all('[data-part="block"]');
const headEls = all('[data-part="head"]');
const writerEl = q('[data-part="writer"]');
const needleEl = q('[data-part="needle"]');
const partitionsEl = q('[data-part="partitions"]');
const readout = document.querySelector("[data-readout]");

const still = matchMedia("(prefers-reduced-motion: reduce)");

let s = create(DEFAULTS);
let speed = 1;
let touring = !still.matches;
let lastTime = performance.now();
let tourClock = 0;

// Tour schedule showing the lifecycle
const TOUR = [
  [8, () => dropConnection(s, 1)],       // Simulate network drop on worker 1
  [18, () => {}],                       // Worker recovers via backoff
  [26, () => invalidateETag(s)],        // Server changes ETag, resets from 0
  [38, () => reconfigure(s, DEFAULTS)], // Reset to fresh transfer
];
const TOUR_LOOP = 42;

function rebuild() {
  if (partitionsEl) {
    partitionsEl.innerHTML = partitionVanesSvg(kit, P, s.c.partitions);
  }
}

function updateDom() {
  // 1. Update blocks
  for (let i = 0; i < s.c.totalSlots; i++) {
    const b = blocks[i];
    if (b) {
      b.innerHTML = blockSvg(kit, P, i, s.slots[i], s.checkpoints[i] === 1);
    }
  }

  // 2. Update heads
  const activeCount = s.c.effectiveWorkers;
  headEls.forEach((el, idx) => {
    if (idx < activeCount) {
      el.style.display = "";
      const p = s.c.partitions[idx];
      const w = s.workers[idx];
      if (p && w) {
        const slotPos = Math.min(p.endSlot - 1, p.startSlot + Math.floor(w.progress));
        const x = X0 + (slotPos + 0.5) * PITCH;
        el.setAttribute("transform", translateAlong(P, [x, 0, 0]));
        const dot = el.querySelector(".iso-dot");
        if (dot) {
          const isStreaming = w.status === "streaming";
          dot.setAttribute("data-tone", isStreaming ? "hi" : "lo");
          dot.style.fill = isStreaming ? "var(--iso-hi)" : "";
        }
      }
    } else {
      el.style.display = "none";
    }
  });

  // 3. Update serialized writer
  if (writerEl) {
    writerEl.innerHTML = writerCarriageSvg(kit, P, s.writer.position, s.writer.isWriting);
  }

  // 4. Update speedometer dial needle
  if (needleEl) {
    needleEl.innerHTML = dialNeedleSvg(kit, P, s.rateMBps, 16);
  }

  // 5. Readout bar
  if (readout) {
    const activeStreams = s.workers.filter(w => w.status === "streaming").length;
    const dlStr = `${s.totalDownloadedMiB.toFixed(1)} / ${s.c.fileMiB} MB`;
    const rateStr = `${s.rateMBps.toFixed(1)} MB/s`;
    let statusText = s.stage;
    if (s.stage === "probe") statusText = "probing (Range: bytes=0-1)";
    else if (s.stage === "transfer") statusText = `transferring (${activeStreams} active)`;
    else if (s.stage === "recovery") statusText = "worker retrying (backoff)";
    else if (s.stage === "complete") statusText = "complete (verified)";

    readout.textContent = `${statusText} · ${dlStr} · ${rateStr}`;
  }

  // 6. Update explorer stats and stage
  if (ex) {
    const activeStreams = s.workers.filter(w => w.status === "streaming").length;
    const verifiedBlocks = s.checkpoints.reduce((a, b) => a + b, 0);
    const retryWorker = s.workers.find(w => w.status === "retrying");
    const retryStr = retryWorker ? `${retryWorker.retryTimer.toFixed(1)}s (att ${retryWorker.retryAttempt})` : "idle";

    ex.setStats({
      workers: `${activeStreams} / ${s.c.effectiveWorkers}`,
      rate: `${s.rateMBps.toFixed(1)} MB/s`,
      downloaded: `${s.totalDownloadedMiB.toFixed(1)} MB`,
      checkpointed: `${verifiedBlocks} / ${s.c.totalSlots}`,
      partitions: `${s.c.effectiveWorkers} spans`,
      retry: retryStr,
      filesize: `${s.c.fileMiB} MB`,
      speed: `${s.c.speedMBps} MB/s`,
    });

    ex.setStage(s.stage);
  }
}

function frame(now) {
  const dt = Math.min(0.1, (now - lastTime) / 1000) * speed;
  lastTime = now;

  if (touring) {
    tourClock = (tourClock + dt) % TOUR_LOOP;
    for (let [triggerAt, action] of TOUR) {
      if (Math.abs(tourClock - triggerAt) < dt * 1.5) {
        action();
      }
    }
  }

  step(s, dt);
  updateDom();

  requestAnimationFrame(frame);
}

// Explorer integration
const ex = Explorer.mount(document.querySelector("[data-explorer]"), {
  presets: PRESETS,
  onChange(changed, values) {
    touring = false;
    reconfigure(s, values);
    rebuild();
  },
  onAction(act, val) {
    if (act === "speed") { speed = val; return; }
    if (act === "tour") { touring = !touring; return; }
    if (act === "play") { togglePause(s); return; }
    if (act === "restart") { reconfigure(s, s.c); return; }
    if (act === "drop") { dropConnection(s, 0); return; }
    if (act === "etag") { invalidateETag(s); return; }
  },
});

const legendEl = document.querySelector(".ex-legend ul") || document.querySelector(".iso-legend");
if (legendEl) {
  Explorer.legend(legendEl, stage);
}

// Keyboard shortcuts
stage.addEventListener("keydown", (e) => {
  if (e.code === "Space") {
    e.preventDefault();
    togglePause(s);
  }
});

rebuild();
requestAnimationFrame(frame);
