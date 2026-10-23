// Torrent streaming, as Sentorr's engine schedules it. The rules and fixed
// numbers are the engine's own (packages/torrent_stream, lib/player/stream);
// the film, its pieces and the swarm are the reader's to configure.

export const SOCKETS = 36; // pieces the tray can hold
export const MAX_PEERS = 6;
// media_kit_adapter.dart: mpv starts after 2 s of cache and reads 60 s ahead.
export const READY_S = 2;
export const CACHE_S = 60;
// A player that stops reading for 3 s releases the start hold; one that has
// read a contiguous urgent window since the seek releases it too.
export const IDLE_S = 3;
// How a swarm's speed splits over its connections: some peers are faster.
const SHARE = [0.25, 0.2, 0.17, 0.15, 0.13, 0.1];
const MIB = 1024 * 1024;

export const DEFAULTS = {
  mbps: 10, // film bitrate, Mbit/s
  pieceMiB: 2,
  lengthS: 60,
  peers: 6,
  swarmMBps: 3, // all peers together, MB/s
  aheadMin: 10, // 0 downloads the entire file while it is open
};

/** Everything that follows from a configuration. */
export function derive(input) {
  const c = { ...DEFAULTS, ...input };
  const PIECE = c.pieceMiB * MIB;
  const RATE = (c.mbps * 1e6) / 8;
  const PIECE_S = PIECE / RATE;
  const maxLength = SOCKETS * PIECE_S;
  const LENGTH_S = Math.min(Math.max(c.lengthS, PIECE_S), maxLength);
  const N = Math.min(SOCKETS, Math.max(1, Math.ceil(LENGTH_S / PIECE_S - 1e-9)));
  // torrent_bytes.dart: about 8 s of video is time-critical, 2–64 MiB, ≤ 16 pieces.
  const URGENT_BYTES = Math.min(64 * MIB, Math.max(2 * MIB, RATE * 8));
  const URGENT = Math.min(16, Math.max(1, Math.ceil(URGENT_BYTES / PIECE)));
  // Deadlines are spaced by the playback each piece holds, 100–4000 ms.
  const STEP_MS = Math.min(4000, Math.max(100, Math.floor((PIECE * 1000) / RATE)));
  const weights = SHARE.slice(0, c.peers);
  const total = weights.reduce((a, b) => a + b, 0);
  const PEERS = weights.map((w) => (w / total) * c.swarmMBps * 1e6);
  return { ...c, PIECE, RATE, PIECE_S, maxLength, LENGTH_S, N, URGENT_BYTES, URGENT, STEP_MS, PEERS };
}

// Fixed rarity, so background pieces arrive rarest-first, out of order.
const RARITY = Array.from({ length: SOCKETS }, (_, i) => ((i * 7919 + 13) % 97) / 97);

export function create(config) {
  const c = derive(config);
  return {
    c,
    have: new Float64Array(c.N),
    pos: 0,
    phase: "starting", // starting | playing | buffering | ended
    paused: false,
    starting: true, // the engine's start hold: disk window held back
    from: 0, // the piece the hold's contiguous run starts at
    quiet: 0, // seconds the player has not read during the hold
    clearing: 0,
    heads: Array.from({ length: MAX_PEERS }, (_, i) => ({ x: parkOf(i), rate: c.PEERS[i] ?? 0, piece: -1, busy: false })),
  };
}

/** Changes the swarm without touching the film: peers and speed apply live. */
export function retune(s, config) {
  s.c = derive({ ...s.c, ...config });
  s.heads.forEach((head, i) => (head.rate = s.c.PEERS[i] ?? 0));
}

// Idle heads park past the tray's end, so the fastest peers (lowest index)
// always take the soonest deadlines.
export const parkOf = (i) => SOCKETS + 0.6 + i;
export const pieceAt = (s, seconds) => Math.min(s.c.N - 1, Math.max(0, Math.floor(seconds / s.c.PIECE_S + 1e-9)));

export function firstMissing(s, from) {
  for (let i = from; i < s.c.N; i++) if (s.have[i] < 1) return i;
  return s.c.N;
}

/** Seconds of verified, contiguous media ahead of the position (mpv's cache). */
export function cacheOf(s) {
  const edge = Math.min(s.c.LENGTH_S, firstMissing(s, pieceAt(s, s.pos)) * s.c.PIECE_S);
  return Math.max(0, Math.min(CACHE_S, edge - s.pos));
}

/** The piece mpv's HTTP read is waiting on: the urgent window starts here. */
export function readerOf(s) {
  const full = pieceAt(s, Math.min(s.c.LENGTH_S - 1e-6, s.pos + CACHE_S));
  return Math.min(firstMissing(s, pieceAt(s, s.pos)), full, s.c.N - 1);
}

/** Priority and deadline of every piece, as PieceScheduler sets them. */
export function windowsOf(s) {
  const { N, URGENT, STEP_MS, aheadMin } = s.c;
  const priority = new Int8Array(N);
  const deadline = new Float64Array(N).fill(Infinity);
  const reader = readerOf(s);
  if (s.clearing > 0) return { priority, deadline, reader };
  if (!s.starting) {
    // A limit runs from the position; the entire file includes what is behind it.
    const [from, end] = aheadMin > 0 ? [pieceAt(s, s.pos), pieceAt(s, s.pos + aheadMin * 60)] : [0, N - 1];
    for (let i = from; i <= end; i++) priority[i] = 5;
  }
  for (let k = 0; k < URGENT && reader + k < N; k++) {
    priority[reader + k] = 7;
    deadline[reader + k] = k * STEP_MS;
  }
  return { priority, deadline, reader };
}

/** The pieces the peers work on: deadlines first, then rarest-first. */
export function targetsOf(s, w) {
  const wanted = [];
  for (let i = 0; i < s.c.N; i++) if (w.priority[i] > 0 && s.have[i] < 1) wanted.push(i);
  wanted.sort((a, b) => w.priority[b] - w.priority[a] || w.deadline[a] - w.deadline[b] || RARITY[a] - RARITY[b]);
  return wanted.slice(0, s.c.peers).sort((a, b) => a - b);
}

export function seek(s, seconds) {
  s.pos = Math.min(s.c.LENGTH_S - 0.05, Math.max(0, seconds));
  s.phase = "starting";
  // prepareSeek cancels obsolete reads; verified pieces stay.
  s.starting = true;
  s.from = pieceAt(s, s.pos);
  s.quiet = 0;
}

export function reset(s) {
  s.clearing = 0.8;
}

export function step(s, dt) {
  const { N, PIECE, LENGTH_S, URGENT_BYTES } = s.c;
  if (s.clearing > 0) {
    s.clearing -= dt;
    for (let i = 0; i < N; i++) s.have[i] = Math.max(0, s.have[i] - dt / 0.6);
    if (s.clearing <= 0) {
      s.clearing = 0;
      s.have.fill(0);
      s.paused = false;
      seek(s, 0);
    }
  }
  const w = windowsOf(s);
  const targets = targetsOf(s, w);
  s.heads.forEach((head, i) => {
    head.piece = i < targets.length ? targets[i] : -1;
    const to = head.piece < 0 ? parkOf(i) : head.piece;
    head.x += (to - head.x) * (1 - Math.exp(-dt / 0.22));
    if (Math.abs(to - head.x) < 0.004) head.x = to;
    head.busy = head.piece >= 0 && Math.abs(to - head.x) < 0.08;
    if (head.busy) s.have[head.piece] = Math.min(1, s.have[head.piece] + (head.rate * dt) / PIECE);
  });

  const cache = cacheOf(s);
  // The start hold ends once the player has read a contiguous urgent window.
  if (s.starting) {
    const edge = firstMissing(s, s.from);
    s.quiet = cache >= CACHE_S ? s.quiet + dt : 0;
    if ((edge - s.from) * PIECE >= URGENT_BYTES || edge === N || s.quiet >= IDLE_S) s.starting = false;
  }
  if (s.pos >= LENGTH_S - 0.05) s.phase = "ended";
  else if (s.phase === "starting" || s.phase === "buffering") {
    if (cache >= READY_S || s.pos + cache >= LENGTH_S - 0.05) s.phase = "playing";
  } else if (s.phase === "playing" && cache <= 1e-3) s.phase = "buffering";
  if (s.phase === "playing" && !s.paused) s.pos = Math.min(LENGTH_S - 0.05, s.pos + Math.min(dt, cache));
  return w;
}

export const speedOf = (s) => s.heads.reduce((sum, head) => sum + (head.busy ? head.rate : 0), 0);
